#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2bth.h>
#include <bthsdpdef.h>
#include <bluetoothapis.h>
#include <windows.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Audio.h>
#include <winrt/Windows.Devices.Enumeration.h>

#include <iostream>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <atomic>
#include <sstream>
#include <iomanip>
#include <chrono>
#include <csignal>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "bthprops.lib")
#pragma comment(lib, "windowsapp.lib")

using namespace winrt;
using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Media::Audio;
using namespace winrt::Windows::Devices::Enumeration;

// Ever Dialer Sync UUID: fa87c0d0-afac-11de-8a39-0800200c9a66
static const GUID EVER_DIALER_SYNC_UUID = {
    0xfa87c0d0, 0xafac, 0x11de, { 0x8a, 0x39, 0x08, 0x00, 0x20, 0x0c, 0x9a, 0x66 }
};

// Standard SPP UUID: 00001101-0000-1000-8000-00805f9b34fb
static const GUID SPP_UUID = {
    0x00001101, 0x0000, 0x1000, { 0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb }
};

static std::atomic<bool> g_running(true);
static std::atomic<bool> g_audioEnabled(true);
static SOCKET g_activeClientSock = INVALID_SOCKET;
static SOCKET g_serverSock = INVALID_SOCKET;
static std::mutex g_sockMutex;
static std::mutex g_coutMutex;
static std::mutex g_audioMutex;
static int g_connCounter = 0;
static int g_activeConnId = 0;

static WSAQUERYSETW g_qsEverDialer = { 0 };
static WSAQUERYSETW g_qsSpp = { 0 };
static bool g_sdpEverDialerRegistered = false;
static bool g_sdpSppRegistered = false;

static AudioPlaybackConnection g_audioConn{ nullptr };
static std::string g_currentPhoneMac = "";

void log_msg(const std::string& msg) {
    std::cerr << "[EverDialerBT-Win] " << msg << std::endl;
}

void emit_event(const std::string& json_str) {
    std::lock_guard<std::mutex> lock(g_coutMutex);
    std::cout << json_str << "\n";
    std::cout.flush();
}

std::string bthAddrToString(BTH_ADDR addr) {
    std::ostringstream oss;
    for (int i = 5; i >= 0; --i) {
        unsigned char b = (unsigned char)((addr >> (i * 8)) & 0xFF);
        oss << std::hex << std::uppercase << std::setfill('0') << std::setw(2) << (int)b;
        if (i > 0) oss << ":";
    }
    return oss.str();
}

BTH_ADDR stringToBthAddr(const std::string& str) {
    BTH_ADDR addr = 0;
    int shift = 40;
    for (size_t i = 0; i < str.length(); ++i) {
        char c = str[i];
        int val = -1;
        if (c >= '0' && c <= '9') val = c - '0';
        else if (c >= 'a' && c <= 'f') val = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') val = c - 'A' + 10;
        if (val != -1) {
            addr |= ((BTH_ADDR)val << shift);
            shift -= 4;
            if (shift < 0) break;
        }
    }
    return addr;
}

std::string getDeviceName(BTH_ADDR addr) {
    BLUETOOTH_DEVICE_INFO btdi = { 0 };
    btdi.dwSize = sizeof(BLUETOOTH_DEVICE_INFO);
    btdi.Address.ullLong = addr;
    if (BluetoothGetDeviceInfo(NULL, &btdi) == ERROR_SUCCESS) {
        char nameBuf[512] = { 0 };
        WideCharToMultiByte(CP_UTF8, 0, btdi.szName, -1, nameBuf, sizeof(nameBuf) - 1, NULL, NULL);
        if (nameBuf[0] != '\0') return std::string(nameBuf);
    }
    return "Mobile Device";
}

// -------------------------------------------------------------
// Audio Playback Connection (A2DP Bluetooth Sink / Spoofed Speaker)
// -------------------------------------------------------------
void stop_audio_sink() {
    std::lock_guard<std::mutex> lock(g_audioMutex);
    if (g_audioConn) {
        try {
            log_msg("Stopping AudioPlaybackConnection");
            g_audioConn.Close();
        } catch (...) {}
        g_audioConn = nullptr;
    }
}

bool start_audio_sink(const std::string& targetMac = "") {
    std::lock_guard<std::mutex> lock(g_audioMutex);
    if (!g_audioEnabled) {
        return false;
    }

    try {
        if (g_audioConn && g_audioConn.State() == AudioPlaybackConnectionState::Opened) {
            return true;
        }

        auto selector = AudioPlaybackConnection::GetDeviceSelector();
        auto devices = DeviceInformation::FindAllAsync(selector).get();
        if (devices.Size() == 0) {
            log_msg("No AudioPlaybackConnection devices discovered yet");
            return false;
        }

        DeviceInformation selectedDev{ nullptr };
        std::string cleanedTargetMac = targetMac;
        // Strip colons for comparison with device IDs
        std::string strippedMac = "";
        for (char c : targetMac) {
            if (c != ':') strippedMac += (char)toupper(c);
        }

        for (uint32_t i = 0; i < devices.Size(); ++i) {
            auto dev = devices.GetAt(i);
            std::wstring devIdW = dev.Id().c_str();
            std::string devId(devIdW.begin(), devIdW.end());
            for (char& c : devId) c = (char)toupper(c);

            if (!strippedMac.empty()) {
                if (devId.find(strippedMac) != std::string::npos) {
                    selectedDev = dev;
                    break;
                }
            } else {
                selectedDev = dev;
                break;
            }
        }

        if (!selectedDev) {
            selectedDev = devices.GetAt(0);
        }

        if (selectedDev) {
            std::wstring devNameW = selectedDev.Name().c_str();
            std::string devName(devNameW.begin(), devNameW.end());
            log_msg("Attempting AudioPlaybackConnection to: " + devName);

            auto conn = AudioPlaybackConnection::TryCreateFromId(selectedDev.Id());
            if (conn) {
                conn.StateChanged([](AudioPlaybackConnection const& sender, IInspectable const&) {
                    int stateVal = (int)sender.State();
                    if (stateVal == 1) { // Opened
                        log_msg("AudioPlaybackConnection OPENED! PC is receiving phone audio as external speaker.");
                        emit_event("{\"event\":\"audio_status\",\"active\":true}");
                    } else if (stateVal == 0) { // Closed
                        log_msg("AudioPlaybackConnection closed");
                        emit_event("{\"event\":\"audio_status\",\"active\":false}");
                    }
                });

                conn.Start();
                auto openRes = conn.OpenAsync().get();
                if ((int)openRes.Status() == 0) {
                    g_audioConn = conn;
                    log_msg("Successfully established A2DP Sink audio connection to " + devName);
                    emit_event("{\"event\":\"audio_status\",\"active\":true,\"device\":\"" + devName + "\"}");
                    return true;
                } else {
                    log_msg("conn.OpenAsync() returned status: " + std::to_string((int)openRes.Status()));
                }
            }
        }
    } catch (const hresult_error& ex) {
        std::wstring msg = ex.message().c_str();
        std::string sMsg(msg.begin(), msg.end());
        log_msg("AudioPlaybackConnection WinRT exception: " + sMsg);
    } catch (const std::exception& e) {
        log_msg("AudioPlaybackConnection exception: " + std::string(e.what()));
    }
    return false;
}

void audio_watchdog_thread() {
    while (g_running) {
        std::this_thread::sleep_for(std::chrono::seconds(4));
        if (!g_running) break;

        if (g_audioEnabled) {
            bool needStart = false;
            {
                std::lock_guard<std::mutex> lock(g_audioMutex);
                if (!g_audioConn || g_audioConn.State() != AudioPlaybackConnectionState::Opened) {
                    needStart = true;
                }
            }
            if (needStart) {
                start_audio_sink(g_currentPhoneMac);
            }
        }
    }
}

// -------------------------------------------------------------
// Phone Data Processing
// -------------------------------------------------------------
void process_phone_line(const std::string& line, int connId) {
    if (line.empty()) return;

    // If line already contains "event": emit directly
    if (line.find("\"event\"") != std::string::npos) {
        emit_event(line);
        return;
    }

    // Extract "type"
    size_t typePos = line.find("\"type\"");
    std::string eventName = "sync_data";
    if (typePos != std::string::npos) {
        size_t colon = line.find(':', typePos);
        if (colon != std::string::npos) {
            size_t q1 = line.find('\"', colon);
            if (q1 != std::string::npos) {
                size_t q2 = line.find('\"', q1 + 1);
                if (q2 != std::string::npos) {
                    eventName = line.substr(q1 + 1, q2 - q1 - 1);
                }
            }
        }
    }

    // Extract "payload"
    size_t payloadPos = line.find("\"payload\"");
    if (payloadPos != std::string::npos) {
        size_t colon = line.find(':', payloadPos);
        if (colon != std::string::npos) {
            size_t valStart = line.find_first_not_of(" \t\r\n", colon + 1);
            if (valStart != std::string::npos) {
                size_t lastBrace = line.rfind('}');
                if (lastBrace != std::string::npos && lastBrace > valStart) {
                    std::string payloadStr = line.substr(valStart, lastBrace - valStart);
                    while (!payloadStr.empty() && (payloadStr.back() == ' ' || payloadStr.back() == '\t' || payloadStr.back() == ',')) {
                        payloadStr.pop_back();
                    }
                    std::string out = "{\"event\":\"" + eventName + "\",\"payload\":" + payloadStr + "}";
                    emit_event(out);
                    return;
                }
            }
        }
    }

    // Fallback: wrap line as payload
    std::string out = "{\"event\":\"" + eventName + "\",\"payload\":" + line + "}";
    emit_event(out);
}

void handle_socket_connection(SOCKET clientSock, BTH_ADDR peerAddr, std::string explicitDevName = "") {
    int myConnId = 0;
    {
        std::lock_guard<std::mutex> lock(g_sockMutex);
        g_connCounter++;
        myConnId = g_connCounter;
        g_activeConnId = myConnId;

        if (g_activeClientSock != INVALID_SOCKET) {
            log_msg("New connection incoming; closing previous socket");
            shutdown(g_activeClientSock, SD_BOTH);
            closesocket(g_activeClientSock);
            g_activeClientSock = INVALID_SOCKET;
        }
        g_activeClientSock = clientSock;
    }

    std::string macStr = bthAddrToString(peerAddr);
    std::string devName = explicitDevName.empty() ? getDeviceName(peerAddr) : explicitDevName;
    g_currentPhoneMac = macStr;

    log_msg("Connection established with " + devName + " (MAC: " + macStr + ") [conn #" + std::to_string(myConnId) + "]");

    // Emit status event
    std::ostringstream ss;
    ss << "{\"event\":\"status\",\"connected\":true,\"device\":\"" << devName << "\",\"mac\":\"" << macStr << "\"}";
    emit_event(ss.str());

    // Automatically initialize A2DP Audio Sink connection for this phone so phone audio routes to PC speakers
    std::thread([macStr]() {
        start_audio_sink(macStr);
    }).detach();

    // Immediately request telemetry
    const char* telemReq = "{\"cmd\": \"request_telemetry\"}\n";
    send(clientSock, telemReq, (int)strlen(telemReq), 0);
    log_msg("Sent immediate request_telemetry to " + devName);

    // Read loop
    DWORD timeout = 2500;
    setsockopt(clientSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

    std::vector<char> buffer;
    buffer.reserve(65536);
    char chunk[4096];

    while (g_running) {
        {
            std::lock_guard<std::mutex> lock(g_sockMutex);
            if (g_activeConnId != myConnId) {
                log_msg("Connection #" + std::to_string(myConnId) + " superseded by #" + std::to_string(g_activeConnId));
                break;
            }
        }

        int bytesRead = recv(clientSock, chunk, sizeof(chunk), 0);
        if (bytesRead > 0) {
            buffer.insert(buffer.end(), chunk, chunk + bytesRead);

            // Process all newline-delimited lines
            size_t start = 0;
            for (size_t i = 0; i < buffer.size(); ++i) {
                if (buffer[i] == '\n') {
                    std::string line(buffer.begin() + start, buffer.begin() + i);
                    while (!line.empty() && (line.back() == '\r' || line.back() == ' ')) {
                        line.pop_back();
                    }
                    if (!line.empty()) {
                        process_phone_line(line, myConnId);
                    }
                    start = i + 1;
                }
            }
            if (start > 0) {
                buffer.erase(buffer.begin(), buffer.begin() + start);
            }
        } else if (bytesRead == 0) {
            log_msg("Socket #" + std::to_string(myConnId) + " closed by remote device");
            break;
        } else {
            int err = WSAGetLastError();
            if (err == WSAETIMEDOUT) {
                continue; // Normal timeout to check g_running
            }
            log_msg("Socket #" + std::to_string(myConnId) + " read error: " + std::to_string(err));
            break;
        }
    }

    bool wasActive = false;
    {
        std::lock_guard<std::mutex> lock(g_sockMutex);
        if (g_activeConnId == myConnId) {
            wasActive = true;
            g_activeClientSock = INVALID_SOCKET;
        }
    }

    closesocket(clientSock);

    if (wasActive) {
        emit_event("{\"event\":\"status\",\"connected\":false}");
        log_msg("Client #" + std::to_string(myConnId) + " disconnected");
    } else {
        log_msg("Superseded client #" + std::to_string(myConnId) + " cleaned up");
    }
}

void try_connect_rfcomm(const std::string& macStr) {
    BTH_ADDR addr = stringToBthAddr(macStr);
    if (addr == 0) {
        log_msg("Invalid MAC address: " + macStr);
        return;
    }

    {
        std::lock_guard<std::mutex> lock(g_sockMutex);
        if (g_activeClientSock != INVALID_SOCKET) {
            return;
        }
    }

    log_msg("Attempting outgoing RFCOMM connect to " + macStr + "...");
    SOCKET sock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
    if (sock == INVALID_SOCKET) {
        log_msg("socket() failed: " + std::to_string(WSAGetLastError()));
        return;
    }

    DWORD timeout = 3500;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&timeout, sizeof(timeout));

    // Try Strategy A: Channel 4
    SOCKADDR_BTH sa = { 0 };
    sa.addressFamily = AF_BTH;
    sa.btAddr = addr;
    sa.port = 4;

    int res = connect(sock, (SOCKADDR*)&sa, sizeof(sa));
    if (res == 0) {
        log_msg("Connected outgoing to " + macStr + " on channel 4");
        std::thread(handle_socket_connection, sock, addr, "").detach();
        return;
    }

    // Try Strategy B: Ever Dialer GUID
    closesocket(sock);
    sock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
    if (sock != INVALID_SOCKET) {
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&timeout, sizeof(timeout));

        ZeroMemory(&sa, sizeof(sa));
        sa.addressFamily = AF_BTH;
        sa.btAddr = addr;
        sa.serviceClassId = EVER_DIALER_SYNC_UUID;

        res = connect(sock, (SOCKADDR*)&sa, sizeof(sa));
        if (res == 0) {
            log_msg("Connected outgoing to " + macStr + " via Ever Dialer UUID");
            std::thread(handle_socket_connection, sock, addr, "").detach();
            return;
        }
        closesocket(sock);
    }

    log_msg("Outgoing connect to " + macStr + " failed");
}

void rfcomm_server_thread() {
    g_serverSock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
    if (g_serverSock == INVALID_SOCKET) {
        log_msg("Failed to create RFCOMM server socket: " + std::to_string(WSAGetLastError()));
        return;
    }

    SOCKADDR_BTH sa = { 0 };
    sa.addressFamily = AF_BTH;
    sa.port = BT_PORT_ANY;

    if (bind(g_serverSock, (SOCKADDR*)&sa, sizeof(sa)) != 0) {
        log_msg("bind() failed: " + std::to_string(WSAGetLastError()));
        closesocket(g_serverSock);
        g_serverSock = INVALID_SOCKET;
        return;
    }

    int saLen = sizeof(sa);
    if (getsockname(g_serverSock, (SOCKADDR*)&sa, &saLen) != 0) {
        log_msg("getsockname() failed: " + std::to_string(WSAGetLastError()));
        closesocket(g_serverSock);
        g_serverSock = INVALID_SOCKET;
        return;
    }

    log_msg("RFCOMM server bound to channel " + std::to_string(sa.port));

    if (listen(g_serverSock, 2) != 0) {
        log_msg("listen() failed: " + std::to_string(WSAGetLastError()));
        closesocket(g_serverSock);
        g_serverSock = INVALID_SOCKET;
        return;
    }

    // Register SDP Service 1: Ever Dialer Sync UUID
    static CSADDR_INFO csAddr1 = { 0 };
    csAddr1.LocalAddr.lpSockaddr = (SOCKADDR*)&sa;
    csAddr1.LocalAddr.iSockaddrLength = sizeof(sa);
    csAddr1.iSocketType = SOCK_STREAM;
    csAddr1.iProtocol = BTHPROTO_RFCOMM;

    static GUID guidEverDialer = EVER_DIALER_SYNC_UUID;
    g_qsEverDialer.dwSize = sizeof(g_qsEverDialer);
    g_qsEverDialer.lpszServiceInstanceName = (LPWSTR)L"EverDialerSync";
    g_qsEverDialer.lpServiceClassId = &guidEverDialer;
    g_qsEverDialer.dwNameSpace = NS_BTH;
    g_qsEverDialer.dwNumberOfCsAddrs = 1;
    g_qsEverDialer.lpcsaBuffer = &csAddr1;

    if (WSASetServiceW(&g_qsEverDialer, RNRSERVICE_REGISTER, 0) == 0) {
        g_sdpEverDialerRegistered = true;
        log_msg("Registered SDP service record for Ever Dialer UUID");
    } else {
        log_msg("Warning: WSASetService for Ever Dialer UUID failed: " + std::to_string(WSAGetLastError()));
    }

    // Register SDP Service 2: Standard SPP UUID
    static CSADDR_INFO csAddr2 = { 0 };
    csAddr2.LocalAddr.lpSockaddr = (SOCKADDR*)&sa;
    csAddr2.LocalAddr.iSockaddrLength = sizeof(sa);
    csAddr2.iSocketType = SOCK_STREAM;
    csAddr2.iProtocol = BTHPROTO_RFCOMM;

    static GUID guidSpp = SPP_UUID;
    g_qsSpp.dwSize = sizeof(g_qsSpp);
    g_qsSpp.lpszServiceInstanceName = (LPWSTR)L"SerialPort";
    g_qsSpp.lpServiceClassId = &guidSpp;
    g_qsSpp.dwNameSpace = NS_BTH;
    g_qsSpp.dwNumberOfCsAddrs = 1;
    g_qsSpp.lpcsaBuffer = &csAddr2;

    if (WSASetServiceW(&g_qsSpp, RNRSERVICE_REGISTER, 0) == 0) {
        g_sdpSppRegistered = true;
        log_msg("Registered SDP service record for SPP UUID");
    }

    emit_event("{\"event\":\"status\",\"connected\":false,\"state\":\"listening\"}");

    DWORD timeout = 1000;
    setsockopt(g_serverSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

    while (g_running) {
        SOCKADDR_BTH clientAddr = { 0 };
        int clientLen = sizeof(clientAddr);
        SOCKET clientSock = accept(g_serverSock, (SOCKADDR*)&clientAddr, &clientLen);
        if (clientSock != INVALID_SOCKET) {
            log_msg("Accepted incoming client connection from " + bthAddrToString(clientAddr.btAddr));
            std::thread(handle_socket_connection, clientSock, clientAddr.btAddr, "").detach();
        } else {
            int err = WSAGetLastError();
            if (err != WSAETIMEDOUT && err != WSAEWOULDBLOCK) {
                if (g_running) {
                    Sleep(500);
                }
            }
        }
    }
}

void stdin_listener() {
    std::string line;
    while (g_running && std::getline(std::cin, line)) {
        while (!line.empty() && (line.back() == '\r' || line.back() == ' ')) {
            line.pop_back();
        }
        if (line.empty()) continue;

        log_msg("PC command received: " + line);

        if (line.find("\"cmd\":\"start_audio\"") != std::string::npos ||
            line.find("\"cmd\": \"start_audio\"") != std::string::npos) {
            g_audioEnabled = true;
            std::thread([]() { start_audio_sink(g_currentPhoneMac); }).detach();
            continue;
        }

        if (line.find("\"cmd\":\"stop_audio\"") != std::string::npos ||
            line.find("\"cmd\": \"stop_audio\"") != std::string::npos) {
            g_audioEnabled = false;
            stop_audio_sink();
            continue;
        }

        if (line.find("\"cmd\":\"repair_audio\"") != std::string::npos ||
            line.find("\"cmd\": \"repair_audio\"") != std::string::npos) {
            g_audioEnabled = true;
            stop_audio_sink();
            std::this_thread::sleep_for(std::chrono::milliseconds(300));
            std::thread([]() { start_audio_sink(g_currentPhoneMac); }).detach();
            continue;
        }

        if (line.find("\"cmd\":\"disconnect\"") != std::string::npos ||
            line.find("\"cmd\": \"disconnect\"") != std::string::npos) {
            std::lock_guard<std::mutex> lock(g_sockMutex);
            if (g_activeClientSock != INVALID_SOCKET) {
                shutdown(g_activeClientSock, SD_BOTH);
                closesocket(g_activeClientSock);
                g_activeClientSock = INVALID_SOCKET;
            }
            continue;
        }

        if (line.find("\"cmd\":\"connect\"") != std::string::npos ||
            line.find("\"cmd\": \"connect\"") != std::string::npos) {
            size_t macPos = line.find("\"mac\"");
            if (macPos != std::string::npos) {
                size_t colon = line.find(':', macPos);
                if (colon != std::string::npos) {
                    size_t q1 = line.find('\"', colon);
                    if (q1 != std::string::npos) {
                        size_t q2 = line.find('\"', q1 + 1);
                        if (q2 != std::string::npos) {
                            std::string targetMac = line.substr(q1 + 1, q2 - q1 - 1);
                            if (!targetMac.empty()) {
                                std::thread(try_connect_rfcomm, targetMac).detach();
                                std::thread([targetMac]() { start_audio_sink(targetMac); }).detach();
                                continue;
                            }
                        }
                    }
                }
            }
        }

        // Forward to connected phone
        {
            std::lock_guard<std::mutex> lock(g_sockMutex);
            if (g_activeClientSock != INVALID_SOCKET) {
                std::string toSend = line + "\n";
                int sent = send(g_activeClientSock, toSend.c_str(), (int)toSend.length(), 0);
                if (sent > 0) {
                    log_msg("Successfully transmitted command to phone over Bluetooth");
                } else {
                    log_msg("Failed to forward stdin command to mobile: " + std::to_string(WSAGetLastError()));
                }
            } else {
                log_msg("Cannot forward command: phone is not connected via Bluetooth");
            }
        }
    }
    g_running = false;
}

void signalHandler(int signum) {
    log_msg("Signal received (" + std::to_string(signum) + "), stopping...");
    g_running = false;
}

int main() {
    // Single instance mutex
    HANDLE hMutex = CreateMutexW(NULL, TRUE, L"EverDialer_BTSync_Daemon_Lock");
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        log_msg("Another daemon instance is already active. Exiting cleanly.");
        if (hMutex) CloseHandle(hMutex);
        return 0;
    }

    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);

    try {
        init_apartment();
    } catch (...) {}

    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        log_msg("WSAStartup failed");
        if (hMutex) CloseHandle(hMutex);
        return 1;
    }

    emit_event("{\"event\":\"status\",\"connected\":false,\"state\":\"starting\"}");

    // Background RFCOMM Server
    std::thread serverThread(rfcomm_server_thread);
    serverThread.detach();

    // Background Audio Watchdog (A2DP Bluetooth Sink / Audio Receiver)
    std::thread audioThread(audio_watchdog_thread);
    audioThread.detach();

    // Initial audio sink connection check (if phone already paired)
    std::thread([]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        start_audio_sink();
    }).detach();

    // Stdin command listener
    std::thread stdinThread(stdin_listener);
    stdinThread.detach();

    while (g_running) {
        Sleep(500);
    }

    stop_audio_sink();

    // Cleanup SDP
    if (g_sdpEverDialerRegistered) {
        WSASetServiceW(&g_qsEverDialer, RNRSERVICE_DEREGISTER, 0);
    }
    if (g_sdpSppRegistered) {
        WSASetServiceW(&g_qsSpp, RNRSERVICE_DEREGISTER, 0);
    }

    if (g_serverSock != INVALID_SOCKET) {
        closesocket(g_serverSock);
    }
    {
        std::lock_guard<std::mutex> lock(g_sockMutex);
        if (g_activeClientSock != INVALID_SOCKET) {
            closesocket(g_activeClientSock);
        }
    }

    WSACleanup();
    emit_event("{\"event\":\"status\",\"connected\":false,\"state\":\"stopped\"}");
    if (hMutex) CloseHandle(hMutex);
    return 0;
}

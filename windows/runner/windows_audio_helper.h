#ifndef RUNNER_WINDOWS_AUDIO_HELPER_H_
#define RUNNER_WINDOWS_AUDIO_HELPER_H_

#include <windows.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <functiondiscoverykeys_devpkey.h>

#include <string>
#include <vector>

namespace ever_dialer {

struct AudioSinkDevice {
  std::string id;
  std::string name;
  bool is_default = false;
};

inline std::string Utf16ToUtf8(const wchar_t* wstr) {
  if (!wstr) return "";
  int len = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, nullptr, 0, nullptr, nullptr);
  if (len <= 1) return "";
  std::string result(len - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wstr, -1, &result[0], len, nullptr, nullptr);
  return result;
}

inline bool GetMasterVolumeAndMute(int* out_volume, bool* out_muted) {
  if (!out_volume || !out_muted) return false;
  *out_volume = 50;
  *out_muted = false;

  HRESULT hr;
  IMMDeviceEnumerator* pEnumerator = nullptr;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
                        __uuidof(IMMDeviceEnumerator), (void**)&pEnumerator);
  if (FAILED(hr) || !pEnumerator) return false;

  IMMDevice* pDevice = nullptr;
  hr = pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDevice);
  if (SUCCEEDED(hr) && pDevice) {
    IAudioEndpointVolume* pEndpointVolume = nullptr;
    hr = pDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_INPROC_SERVER, nullptr, (void**)&pEndpointVolume);
    if (SUCCEEDED(hr) && pEndpointVolume) {
      float vol = 0.5f;
      pEndpointVolume->GetMasterVolumeLevelScalar(&vol);
      *out_volume = static_cast<int>(vol * 100.0f + 0.5f);

      BOOL isMuted = FALSE;
      pEndpointVolume->GetMute(&isMuted);
      *out_muted = (isMuted != FALSE);

      pEndpointVolume->Release();
    }
    pDevice->Release();
  }
  pEnumerator->Release();
  return true;
}

inline bool SetMasterVolume(int volume) {
  int clamped = volume < 0 ? 0 : (volume > 100 ? 100 : volume);
  float vol = clamped / 100.0f;

  HRESULT hr;
  IMMDeviceEnumerator* pEnumerator = nullptr;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
                        __uuidof(IMMDeviceEnumerator), (void**)&pEnumerator);
  if (FAILED(hr) || !pEnumerator) return false;

  IMMDevice* pDevice = nullptr;
  hr = pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDevice);
  if (SUCCEEDED(hr) && pDevice) {
    IAudioEndpointVolume* pEndpointVolume = nullptr;
    hr = pDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_INPROC_SERVER, nullptr, (void**)&pEndpointVolume);
    if (SUCCEEDED(hr) && pEndpointVolume) {
      pEndpointVolume->SetMasterVolumeLevelScalar(vol, nullptr);
      pEndpointVolume->Release();
    }
    pDevice->Release();
  }
  pEnumerator->Release();
  return true;
}

inline bool SetMasterMute(bool muted) {
  HRESULT hr;
  IMMDeviceEnumerator* pEnumerator = nullptr;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
                        __uuidof(IMMDeviceEnumerator), (void**)&pEnumerator);
  if (FAILED(hr) || !pEnumerator) return false;

  IMMDevice* pDevice = nullptr;
  hr = pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDevice);
  if (SUCCEEDED(hr) && pDevice) {
    IAudioEndpointVolume* pEndpointVolume = nullptr;
    hr = pDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_INPROC_SERVER, nullptr, (void**)&pEndpointVolume);
    if (SUCCEEDED(hr) && pEndpointVolume) {
      pEndpointVolume->SetMute(muted ? TRUE : FALSE, nullptr);
      pEndpointVolume->Release();
    }
    pDevice->Release();
  }
  pEnumerator->Release();
  return true;
}

inline std::vector<AudioSinkDevice> GetAudioSinks() {
  std::vector<AudioSinkDevice> results;
  HRESULT hr;
  IMMDeviceEnumerator* pEnumerator = nullptr;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
                        __uuidof(IMMDeviceEnumerator), (void**)&pEnumerator);
  if (FAILED(hr) || !pEnumerator) return results;

  std::string defaultId;
  IMMDevice* pDefaultDevice = nullptr;
  if (SUCCEEDED(pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDefaultDevice)) && pDefaultDevice) {
    LPWSTR pwszDefID = nullptr;
    if (SUCCEEDED(pDefaultDevice->GetId(&pwszDefID)) && pwszDefID) {
      defaultId = Utf16ToUtf8(pwszDefID);
      CoTaskMemFree(pwszDefID);
    }
    pDefaultDevice->Release();
  }

  IMMDeviceCollection* pCollection = nullptr;
  hr = pEnumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &pCollection);
  if (SUCCEEDED(hr) && pCollection) {
    UINT count = 0;
    pCollection->GetCount(&count);
    for (UINT i = 0; i < count; i++) {
      IMMDevice* pEndpoint = nullptr;
      if (SUCCEEDED(pCollection->Item(i, &pEndpoint)) && pEndpoint) {
        AudioSinkDevice info;
        LPWSTR pwszID = nullptr;
        if (SUCCEEDED(pEndpoint->GetId(&pwszID)) && pwszID) {
          info.id = Utf16ToUtf8(pwszID);
          CoTaskMemFree(pwszID);
        }

        info.is_default = (!defaultId.empty() && info.id == defaultId);

        IPropertyStore* pProps = nullptr;
        if (SUCCEEDED(pEndpoint->OpenPropertyStore(STGM_READ, &pProps)) && pProps) {
          PROPVARIANT varName;
          PropVariantInit(&varName);
          if (SUCCEEDED(pProps->GetValue(PKEY_Device_FriendlyName, &varName))) {
            if (varName.vt == VT_LPWSTR && varName.pwszVal) {
              info.name = Utf16ToUtf8(varName.pwszVal);
            }
          }
          PropVariantClear(&varName);
          pProps->Release();
        }

        if (info.name.empty()) {
          info.name = "Audio Output";
        }
        results.push_back(info);
        pEndpoint->Release();
      }
    }
    pCollection->Release();
  }
  pEnumerator->Release();
  return results;
}

}  // namespace ever_dialer

#endif  // RUNNER_WINDOWS_AUDIO_HELPER_H_

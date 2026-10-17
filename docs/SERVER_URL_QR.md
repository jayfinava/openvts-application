# Server URL QR setup

The QR icon on the login screen opens the camera scanner. Encode the **full API
base URL** as plain QR text, for example:

```text
https://fleet.example.com/api
```

The scanner also accepts a JSON QR payload with an `apiBaseUrl` string:

```json
{"apiBaseUrl":"https://fleet.example.com/api"}
```

The scanned URL is validated using the same rules as the manual form, saved in
local preferences, and used for subsequent API requests. Changing servers
clears credentials issued by the previous server before the new URL is saved.
Invalid QR codes do not change the current URL.

The scanner page keeps **Configure manually** visible. It opens the existing
Server URL form for editing, saving, or resetting the URL. Devices without a
supported camera can use that form. Camera access is requested when scanning
starts; the iOS usage description and Android camera permission are included.

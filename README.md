
# Hermes
Client that is used for bypassing firewalls. 

## Dependencies
- Chromium browser
- ruby
## How to configure?
Configuration file is located at /etc/hermes/config.json

It will be created on first launch. 

Example:

```js
    {
        "server": "example.com",
        "max_buffer": 65535,
        "default_interface": "eth0"
    }
```
- server - domain name of the vpn server
- default_interface - your default interface name
## How to install & run
- Download the deb package from the "Releases"
- install it via dpkg or apt 
```bash
    sudo apt install ./hermes-client.deb
    # or
    sudo dpkg -i ./hermes-client.deb
```
## Brief description
Maybe later...


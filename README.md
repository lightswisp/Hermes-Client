
# Hermes
Client that is used for bypassing firewalls. 

## Demo

https://github.com/lightswisp/Hermes-Client/assets/48927861/12951944-5c54-45c9-b0f5-dd1f080a142f

## Dependencies
- Chromium browser
- ruby
## How to configure?

**Empty configuration file will be created on first launch in the appropriate directory.**

_For Linux_: configuration file is located at /etc/hermes/config.json

_For Windows_: configuration file is located at %APPDATA%/Hermes/config.json


Example:

```js
    {
        "server": "example.com",
        "check_server": "8.8.8.8"
        "max_buffer": 65535,
        "default_interface": "eth0"
    }
```
- server (Required) - Domain name of the vpn server
- check_server (Required) - This is used to verify internet connectivity + obtain your local ip address which is gonna be used later.
- default_interface (optional) - your default interface name
## How to install & run
### Linux 
- Download the deb package from the "Releases"
- install it via dpkg or apt 
```bash
    sudo apt install ./hermes-client.deb
    # or
    sudo dpkg -i ./hermes-client.deb
```
### Windows
Installer will be added a bit later...
- Install ruby from https://rubyinstaller.org/downloads/
- Git clone the repository
- Cd into it 
- Run the following commands: (You need admin rights)
```
    gem install bundler

    bundle install
```
- Now you can run the main script (You need admin rights)
```
    ruby hermes
```
## Brief description of how it works
Maybe later...


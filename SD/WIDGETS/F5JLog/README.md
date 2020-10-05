# F5J Companion 
OpenTX Lua script for tracking and logging F5J flights

Works On OpenTX Version: 2.3.9

Author: Knutigro

## Installation
- Download the latest version: https://github.com/knutigro/F5J-Companion/archive/main.zip
- Copy the contents of the SD folder to your radio SD Card.

## Features
 - Displays flighdata and calculate points according to the F5J rules.
 - Displays logs for the 5 most recent flights current day.

### F5J Companion Widget
![Screenshot](https://github.com/knutigro/F5J-Companion/blob/main/SD/WIDGETS/F5JComp/screenshot.png)
#### Description
Timers will start counting once the StateSwitch is in down position and Throttle is moved to above minimum.
Flight has to be manually stopped by switching the StateSwitch to middle position. This will also automatically save the flight to the logs folder. Logs can be viewed in the F5JLog widget or downloaded to the computer from the [/LOGS/F5JComp/](https://github.com/knutigro/F5J-Companion/tree/main/SD/LOGS/F5JComp) folder.
Setting StateSwitch to up position will reset flight data and telemetry data.

#### Widget Settings
- StateSwitch -> Is used to signal the start of the flight (down), end of the flight and to stop the timers (middle) then reset everything (up).
- Throttle -> Is used to start the timer. Change to your throttle output.
- Altitude -> Telemetry for altitude.
- TotalTime -> Maximum flight time in minutes.

### F5J Logs Widget
![Screenshot](https://github.com/knutigro/F5J-Companion/blob/main/SD/WIDGETS/F5JLog/screenshot.png)
#### Description
Displays the 5 latest flights from from current date.
Complete logs can be found in the [/LOGS/F5JComp/](https://github.com/knutigro/F5J-Companion/tree/main/SD/LOGS/F5JComp) folder.



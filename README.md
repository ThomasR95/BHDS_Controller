# BHDS_Controller

A lua script for DeSmuME to convert XBOX Controller input into a format understood by the game.

## Prerequisites:

In order for this script to run, you need to have lua51.dll and lua-xinput.dll in your PATH or the DeSmuME executable's directory.

Lua can be downloaded [here.](http://luabinaries.sourceforge.net/download.html)
lua-xinput source can be found [here.](https://bitbucket.org/bartbes/lua-xinput/src/5070d7f61f7ecf69eef8373c9b772b4907216d05/xinput.cpp?at=default) 

I have included binaries in this repository for ease of use.

A ROM for Bionicle Heroes DS can be found on [BioMedia Project.](http://biomediaproject.com/bmp/play/retail-games/)

## Setup:

- Ensure the 2 included binaries are in the PATH or the DeSmuME executable directory.
- Open DeSmuME and start Bionicle Heroes.
- Go to Tools > Lua Scripting > New Lua Script Window. From here you can browse and find the BHDS_Controller.lua script.
- Run the script if it doesn't automatically start.

- In Bionicle Heroes's Options menu, select "Button Config" and choose "Right-Handed (key view)" (You can choose left-handed if you want, but this is a little counter-intuitive on an Xbox controller).
- You're set! The controls are as follows:

![Control layout](https://imgur.com/download/ngo99ak)
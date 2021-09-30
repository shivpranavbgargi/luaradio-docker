# LuaRadio as docker image

### Record and listen to FM radio with an RTL-SDR by following the steps below. 

- `$ bash build` to build the docker image
- `$ ./luaradio fm.lua 93.5e6` and let it run for few seconds
- `CTRL+C` to stop the capturing
- `$ exit` to exit the container  
- `$ paplay ./luaradio/wbfm_mono.wav` to play the recording
- `$ bash run` can be used for subsequent runs

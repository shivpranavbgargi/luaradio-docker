#!/bin/bash

if [[ $# -eq 0 ]]; then
  cat << EOF
$ bash run.sh luaradio fm.lua <frequency_in_hz> <output_file_name> to record the fm radio 
$ bash run.sh paplay <output_file_name.wav> to listen to the recording
EOF
  exit 1
fi

if ! cmd_loc="$(type -p docker)" || [[ -z $cmd_loc ]]; then
  echo "Install docker first"
  exit 1
fi

USERID=$(id -u)
DOCKERIMAGE=lua-debian

#function build() builds the docker image

function build() {

local USERNAME=kode

cat << EOF > "etc-pulse-client.conf"
default-server = unix:/run/user/$USERID/pulse/native
autospawn = no
daemon-binary = /bin/true
enable-shm = false
EOF

#lua script for fm radio

git clone https://github.com/vsergeev/luaradio.git

cat << EOF > "./luaradio/fm.lua"
 
local radio = require('radio')

if #arg < 2 then
    io.stderr:write("Usage: " .. arg[0] .. " <FM radio frequency> <Output file name>\n")
    os.exit(1)
end

local frequency = tonumber(arg[1])
local tune_offset = -250e3
local name = arg[2]

-- Blocks
local source = radio.RtlSdrSource(frequency + tune_offset, 1102500)
local tuner = radio.TunerBlock(tune_offset, 200e3, 5)
local fm_demod = radio.FrequencyDiscriminatorBlock(1.25)
local af_filter = radio.LowpassFilterBlock(128, 15e3)
local af_deemphasis = radio.FMDeemphasisFilterBlock(75e-6)
local af_downsampler = radio.DownsamplerBlock(5)
local sink = radio.WAVFileSink(string.format('%s.wav',name), 1)


-- Connections
local top = radio.CompositeBlock()
top:connect(source, tuner, fm_demod, af_filter, af_deemphasis, af_downsampler, sink)

top:run()
EOF

#dockerfile

docker build -t $DOCKERIMAGE -f- . << EOF
FROM debian:stable-slim
RUN apt-get update && apt-get -y install luajit libliquid-dev libfftw3-dev rtl-sdr librtlsdr-dev pulseaudio pulseaudio-utils sudo
COPY etc-pulse-client.conf /etc/pulse/client.conf
RUN addgroup -gid $USERID $USERNAME && adduser --disabled-password -uid $USERID --ingroup $USERNAME $USERNAME
USER $USERNAME
WORKDIR /home/$USERNAME/
ENV PULSE_SERVER=unix:/run/user/$USERID/pulse/native
ENV PATH "$PATH:/home/kode"
EOF

rm etc-pulse-client.conf 

}

#docker build 

if [[ "$(docker images -q $DOCKERIMAGE 2> /dev/null)" == "" ]]; then
  build
fi 

#docker run 

docker run --rm -it --privileged \
       	-v /dev/bus/usb:/dev/bus/usb \
	-v /run/user/$USERID/pulse:/run/user/$USERID/pulse \
	-v ${PWD}/luaradio:/home/kode/ $DOCKERIMAGE $@

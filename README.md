# Containerised VoIP Public Transport Announcement Service
You call. It answers.<br />
<small>You enter a valid Sydney Trains GTFS Stop ID when prompted.</small><br />
*The next train to arrive on Platform 23 goes to...*

> [!NOTE]
> Running the Docker images will shamelessly steal the sound files from [DVA5](https://github.com/jaboles/DVA5).

## Requirements
- A public IPv4 address
- ~20GB of disk space
- A Transport for NSW Open Data Hub API key ([Guide](<https://opendata.transport.nsw.gov.au/developers/userguide>))

## Setup
1. Add a `secrets/` directory to the project root directory, and include:
    - Your API key in `api_key.txt`
    - SIP peer addresses in `sip_match.txt`
    - Your SIP credentials in `sip_server.txt`, `sip_username.txt` and `sip_password.txt`

2. Add your public IPv4 address (e.g. `X.X.X.X/32`) to the [`fail2ban` jail](/images/asterisk/fail2ban/jail.local) `ignoreip` line.

## To Do
- Support for configuring multiple APIs and agencies with individual announcement logic.
- Optimising the AGI for multiple simultaneous calls:
  - Bridging for multiple callers into a single call per station.
  - Retention of GTFS Realtime feed data.
  - Queueing for announcement playback.

## FAQ
<details>
<summary>Why?</summary>

I had become obsessed with New South Wales' train station announcements after visiting Sydney in 2023 and 2026. One [rather nerdy video](https://www.youtube.com/watch?v=nCPpkY1TD9Q) later, I was now interested in telephony and PBXs.

Combining the two, I envisioned a way to listen to live NSW station announcements from anywhere, including my beloved home state of Victoria[^1].

[^1]: *Some* NSW TrainLink announcements play at Southern Cross Station in Melbourne.

</details>

<details>
<summary>Why aren't Intercity or NSW TrainLink services announced?</summary>

They use a separate API, and I have already spent a significant amount of time fixing myriad issues[^2] that I have managed to create. 

[^2]: I have *one* chance each day to see if the API data has updated correctly. As you can imagine, this has drastically increased the time required to reach a functional state.

</details>

<details>
<summary>Why aren't the announcements accurate?</summary>

I require either:
- More information from Transport for NSW about announcement logic; or
- The means to spend a few days in Sydney purely to record train announcements, compile and listen to every recording, and somehow reassemble the inner workings myself.
</details>

<details>
<summary>Why Docker?</summary>

Masochism[^3].

[^3]: Initially, I decided to implement it in Docker to be able to list it on my CV. While there are downsides to running Asterisk in Docker, I eventually found that it was a net positive when testing the project on multiple systems.

</details>

<details>
<summary>Why does the call go silent?</summary>

Usually an issue with retrieving information from the API. I'm working on it.
</details>
#!/usr/local/envs/venv/bin/python3
from asterisk.agi import *
from zoneinfo import ZoneInfo

import datetime
import nsw_gtfs_realtime_pb2
import requests
import sys
import time

stop_id = sys.argv[1]

def get_next_departure_from_stop():
    response = requests.get(
        'https://api.transport.nsw.gov.au/v1/tp/departure_mon?outputFormat=rapidJSON' \
        '&coordOutputFormat=EPSG%3A4326' \
        '&mode=direct' \
        '&type_dm=stop' \
        f'&name_dm={sys.argv[1]}' \
        '&excludedMeans=checkbox&exclMOT_2=1&exclMOT_4=1&exclMOT_5=1&exclMOT_7=1&exclMOT_9=1&exclMOT_11=1' \
        '&TfNSWDM=true&departureMonitorMacro=true',
        headers={
            'content-type': 'application/json',
            'Authorization': f'apikey {open(f'/run/secrets/api_key').read().rstrip('\n')}'
        }
    ).json()
    stop_events = [stop_event for stop_event in response['stopEvents'] if stop_event['transportation']['operator']['name'] == "Sydney Trains"]
    stop_events.sort(key=lambda stop_event: stop_event.get('departureTimeEstimated') or stop_event['departureTimeBaseTimetable'])
    stop_events = [stop_event for stop_event in stop_events if time.time() < datetime.datetime.fromisoformat(stop_event.get('departureTimeEstimated') or stop_event['departureTimeBaseTimetable']).timestamp()]

    return stop_events[0]

def get_timetable_information(trip_id: str, departure_time: str):
    # Get timetable information about the next departure.
    departure_time_formatted = datetime.datetime.fromisoformat(departure_time).astimezone(ZoneInfo('Australia/Sydney')).strftime("%H:%M:%S")
    timetable_information = requests.get(
        'http://postgrest:3000/trips?select=' \
        'trip_headsign,' \
        'stop_times(' \
            'stop_sequence,' \
            'arrival_time,' \
            'departure_time,' \
            'stop_headsign,' \
            'following_stop_times(drop_off_type,...stops(...parent(stop_name))),'\
            '...stops(' \
                'stop_id,' \
                'stop_name,' \
                '...parent(parent_stop_name:stop_name)' \
            ')' \
        ')' \
        '&limit=1' \
        '&stop_times.following_stop_times.order=stop_sequence.asc' \
        '&stop_times.following_stop_times.drop_off_type=eq.false' \
        f'&trip_id=eq.{trip_id}' \
        f'&stop_times.departure_time=like.{departure_time_formatted[:5]}*'
    ).json()
    if not len(timetable_information):
        pass
    else:
        return timetable_information[0]

def get_departure_delay(trip_id: str, stop_id: str = stop_id, stop_sequence = int):
    # Check the next departure's delay
    arrival_delay = 0
    departure_delay = 0

    get_trip_updates = requests.get(
        'https://api.transport.nsw.gov.au/v2/gtfs/realtime/sydneytrains',
        headers = {
            'content-type': 'application/x-google-protobuf',
            'Authorization': f'apikey {open(f'/run/secrets/api_key').read().rstrip('\n')}'
        }
    )
    
    trip_updates = nsw_gtfs_realtime_pb2.FeedMessage()
    trip_updates.ParseFromString(get_trip_updates.content)
    for entity in trip_updates.entity:
        if entity.trip_update.trip.trip_id == trip_id:
            for stop_time_update in entity.trip_update.stop_time_update:
                if stop_time_update.stop_sequence and stop_time_update.stop_sequence != stop_sequence:
                    continue
                if stop_time_update.stop_id and stop_time_update.stop_id != stop_id:
                    continue
                arrival_delay = stop_time_update.arrival.delay
                departure_delay = stop_time_update.departure.delay
                break
    return [arrival_delay, departure_delay]

def play_sound(filename: str) -> None:
    global agi
    agi.stream_file(f'nsw/{filename.replace(' ','-')}')

def play_sounds(filenames: list[str]) -> None:
    global agi
    for filename in filenames:
        play_sound(filename)

def is_service_on_platform(service_realtime, arrival_time: str, departure_time: str, arrival_delay: int) -> bool:
    """
    Determine whether a service has arrived at the station.
    
    @param service_realtime The stop event representing the service, returned from get_next_departure_from_stop.
    @param arrival_time The scheduled arrival time of the service, formatted as an hours, minutes and seconds offset from the beginning of the day on which the service was scheduled to begin.
    @param departure_time The scheduled departure time of the service, formatted as an hours, minutes and seconds offset from the beginning of the day on which the service was scheduled to begin.
    @param arrival_delay The number of seconds by which the service's arrival is delayed.
    """
    arrival_local_hms = [int(x) for x in arrival_time.split(':')]
    departure_local_hms = [int(x) for x in departure_time.split(':')]
    departure_time_actual = datetime.datetime.fromisoformat(service_realtime['departureTimeBaseTimetable'])
    arrival_time_actual = departure_time_actual - datetime.timedelta(hours=departure_local_hms[0], minutes=departure_local_hms[1], seconds=departure_local_hms[2]) + datetime.timedelta(hours=arrival_local_hms[0], minutes=arrival_local_hms[1], seconds=arrival_local_hms[2]) + datetime.timedelta(seconds=arrival_delay)
    return (time.time() - arrival_time_actual.timestamp()) >= 0

agi = AGI()

check_db = requests.get('http://postgrest:3000/trips?limit=1')
if not len(check_db.json()):
    agi.set_context('error')
    agi.set_extension('s')
    agi.set_priority(1)
    sys.exit()

check_stop_id = requests.get('http://postgrest:3000/stops?stop_id=eq.{}'.format(stop_id))
if not len(check_stop_id.json()):
    agi.set_context('invalid_stop_id')
    agi.set_extension('s')
    agi.set_priority(1)
    sys.exit()

service_realtime = get_next_departure_from_stop()
try:
    service_timetable = get_timetable_information(service_realtime['properties']['RealtimeTripId'], service_realtime['departureTimeBaseTimetable'])
except:
    agi.set_context('error')
    agi.set_extension('s')
    agi.set_priority(1)
    sys.exit()

service_platform = service_realtime['location']['properties']['platformName']

try:
    stop_id = service_timetable['stop_times'][0]['stop_id']
except:
    raise Exception(service_timetable, service_realtime)


service_headsign = (service_timetable['stop_times'][0]['stop_headsign'] or service_timetable['trip_headsign']).split(' via ')
service_destination = service_headsign[0]
service_via = service_headsign[1] if len(service_headsign) >= 2 else None
service_stops = [(stop['stop_name']).split(' Station')[0] for stop in service_timetable['stop_times'][0]['following_stop_times']]
service_delays = get_departure_delay(service_realtime['properties']['RealtimeTripId'], stop_sequence=service_timetable['stop_times'][0]['stop_sequence'])

# Begin announcement
play_sound("3 ascending chimes")

# If the service has arrived, announce it as "The train on" instead of "The next train to arrive on"
if is_service_on_platform(service_realtime, service_timetable['stop_times'][0]['arrival_time'], service_timetable['stop_times'][0]['departure_time'], service_delays[0]):
    play_sound(f"The train on {service_platform.lower()}")
else:
    play_sound(f"The next train to arrive on {service_platform.lower()}")

play_sound('goes to')
play_sounds([f'{service_destination}', 'via', f'{service_via}.f'] if service_via else [f'{service_destination}.f'])

if len(service_stops) > 1:
    play_sounds([
        "First stop",
        f"{service_stops[0]}",
        "then"
    ])
    for stop in service_stops[1:-1]:
        play_sound(f"{stop}")
    play_sounds([
        "and",
        f"{service_stops[-1]}"
    ])
else:
    play_sound('only.f')
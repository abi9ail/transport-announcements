#!/bin/bash
newest_modified_date=0
for file in sydneytrains/*.txt
do
	file_modified_date=$(echo `date -d"$(date -r $file)" +%s`)
	if [ $file_modified_date -ge $newest_modified_date ];
	then
		newest_modified_date=$file_modified_date
	fi
done

# Check when the API data was last updated with a HTTP HEAD request
api_modified_date=$(\date +%s -d"$(curl -sI 'https://api.transport.nsw.gov.au/v1/gtfs/schedule/sydneytrains' \
	--header="Authorization: apikey $(cat /run/secrets/api_key)"\
	| grep -oP '(?<=last-modified: .{3}, )(.*)')")

# Prune old timetable entries
psql -c "DELETE FROM calendar WHERE TO_DATE(end_date, 'YYYYMMDD') < current_date + interval '-2 day';"

if [[ $api_modified_date -ge $file_modified_date ]];
then
	echo "Updating files"

	# Download new files
	wget 'https://api.transport.nsw.gov.au/v1/gtfs/schedule/sydneytrains' --header="Authorization: apikey $(cat /run/secrets/api_key)" -P sydneytrains/
	unzip -u sydneytrains/sydneytrains -d sydneytrains
	rm sydneytrains/sydneytrains

	# CSV import to database
	# tables=("agency" "calendar" "stops" "routes" "trips" "stop_times" "occupancies" "shapes" "vehicle_categories" "vehicle_boardings" "vehicle_couplings")
	tables=("agency" "calendar" "stops" "routes" "trips" "stop_times" "shapes")

	# Upload API data to database
	for table in "${tables[@]}";
	do
		psql -c "COPY $table ($(head -n 1 sydneytrains/$table.txt))\
		FROM '$(pwd)/sydneytrains/$table.txt' WITH (FORMAT csv, HEADER true, LOG_VERBOSITY verbose, ON_ERROR ignore, FORCE_NULL *, DEFAULT 'default');"
		wait
	done

	psql -c "VACUUM"
else
	echo "Files up-to-date"
fi
exit 0;
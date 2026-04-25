#!/bin/bash

# Very crude timestamped notebook CLI app.
# For taking notes on my tinkering attempts
# (to retrace steps later, when *everything* breaks and the need inevitably arises).
#
# The system MUST have sqlite3. I won't check that it's there every fricking time.
#
# PS: If you have forgot how you'd written this and have any issues with editing, check your VISUAL/EDITOR env var, stoopid.

EXTERNAL_NAME='tsb';

TIMESTAMP_COLNAME='Time';
NOTE_COLNAME='Note';

MSG_TOO_FEW_ARGUMENTS='Too few arguments.';

create_db_file_if_not_exists() {
	DB_NAME="$1";
	[ ! -f "$DB_NAME" ] && (sqlite3 "$DB_NAME" << EOF
create table notes (note_date integer primary key, note_body text);
EOF
	);
}

# NOTE: No, I won't make this crappy thing ultra-secure.
# 		More info here: http://mywiki.wooledge.org/BashFAQ/062

insert_note_at_editing_end() {
	DB_NAME="$1";
	TMPFILE=$(mktemp -p "${TMPDIR:-/tmp}" note.XXXXXXXXXX);
	${VISUAL:-${EDITOR:-vi}} "${TMPFILE}"; # https://stackoverflow.com/a/60461932
	NOTE=$(< "$TMPFILE"); # https://stackoverflow.com/a/14118355
	sqlite3 "$DB_NAME" << EOF
insert into notes (note_date, note_body) values (unixepoch(), '$NOTE');
EOF
	rm $TMPFILE;
}


show_last_notes() {
	DB_NAME="$1";

	[ $# -lt 2 ] || LIMIT="$2";

	SQL_SHOW_ALL_NOTES=$(cat <<EOF
select datetime(note_date, 'unixepoch', 'localtime') as '$TIMESTAMP_COLNAME',
       note_body as '$NOTE_COLNAME'
from notes
order by note_date asc;
EOF
	);

	SQL_SHOW_LIMITED_NOTES=$(cat <<EOF
select *
from (select datetime(note_date, 'unixepoch', 'localtime') as '$TIMESTAMP_COLNAME',
             note_body as '$NOTE_COLNAME'
     from notes
     order by note_date desc
     limit ${LIMIT})
order by \`${TIMESTAMP_COLNAME}\` asc;
EOF
	);

	[ -z ${LIMIT+x} ] && # https://stackoverflow.com/a/13864829
	echo "${SQL_SHOW_ALL_NOTES}" | sqlite3 "$DB_NAME" ||
	echo "${SQL_SHOW_LIMITED_NOTES}" | sqlite3 "$DB_NAME";
}

show_notes_inside_interval() {
	DB_NAME="$1";
	START="unixepoch('$2', 'utc')";
	END="unixepoch('$3', 'utc')";

	[ $# -lt 3 ] && echo $MSG_TOO_FEW_ARGUMENTS && return 1;

	SQL_SHOW_NOTES_INSIDE_INTERVAL=$(cat <<EOF
select datetime(note_date, 'unixepoch', 'localtime') as '$TIMESTAMP_COLNAME',
       note_body as '$NOTE_COLNAME'
from notes
where note_date >= $START and note_date < $END
order by note_date asc;
EOF
	);

	echo ${SQL_SHOW_NOTES_INSIDE_INTERVAL} | sqlite3 "$DB_NAME";
}

show_notes_today_inside_interval() {
	DB_NAME="$1";

	[ $# -lt 3 ] &&
	END="unixepoch(datetime('now', '+1 day', 'start of day'), 'utc')" ||
	END="unixepoch(datetime('now', 'start of day', '$3'), 'utc')";

	[ $# -lt 2 ] &&
	START="unixepoch(datetime('now', 'start of day'), 'utc')" ||
	START="unixepoch(datetime('now', 'start of day', '$2'), 'utc')";

	SQL_SHOW_NOTES_TODAY_INSIDE_INTERVAL=$(cat <<EOF
select datetime(note_date, 'unixepoch', 'localtime') as '$TIMESTAMP_COLNAME',
       note_body as '$NOTE_COLNAME'
from notes
where note_date >= $START and note_date < $END
order by note_date asc;
EOF
	);

	echo ${SQL_SHOW_NOTES_TODAY_INSIDE_INTERVAL} | sqlite3 "$DB_NAME";
}

USAGE_MSG="Usage: $EXTERNAL_NAME <notebook filename> <command> [<args>]"

main() {
	HELP_MSG=$(cat <<EOF
$USAGE_MSG

Commands:
	n[ote]                      Enter new note in with \$VISUAL or \$EDITOR app. It will be timestamped when saved.
	s[how] [<number>]           Show <number> of most recent notes, or all at once.
	i[nterval] <start> <end>    Show notes taken inside time interval. Format: 'YYYY-MM-DD HH:MM'
	t[oday] [<start> [<end>]]   Show notes taken today inside time interval, or all of them at once. Format: HH:MM
EOF
);

	[ "$1" == "help" ] && echo -e "$HELP_MSG" && return 0;

	[ $# -lt 2 ] && echo $MSG_TOO_FEW_ARGUMENTS && echo -e "$HELP_MSG" && return 0;

	NOTEBOOK_DB="$1";
	COMMAND="$2";

	case "$COMMAND" in
		"note"|"n")
			create_db_file_if_not_exists "$NOTEBOOK_DB";
			insert_note_at_editing_end $NOTEBOOK_DB "${@:3}";
			;;
		"show"|"s")
			create_db_file_if_not_exists "$NOTEBOOK_DB";
			show_last_notes $NOTEBOOK_DB "${@:3}";
			;;
		"interval"|"i")
			create_db_file_if_not_exists "$NOTEBOOK_DB";
			show_notes_inside_interval $NOTEBOOK_DB "${@:3}";
			;;
		"today"|"t")
			create_db_file_if_not_exists "$NOTEBOOK_DB";
			show_notes_today_inside_interval $NOTEBOOK_DB "${@:3}";
			;;
		*)
			echo "Unknown command: $COMMAND";
			;;
	esac
}


main "$@";

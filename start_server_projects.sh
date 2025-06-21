#!/usr/bin/env bash

#script for launching the various game cluster servers
error=0
srvr_name=$2

GODOT_BIN="$HOME/dev/GodotEngine-Builds/Godot_v4.4.1-stable_linux.x86_64"
help() {
	echo "Usage:"
	echo "start_servers_projects.sh help"
	echo "start_servers_projects.sh start {authsrvr|gmsrvr|gwsrvr}"
	echo "start_servers_projects.sh stop {authsrvr|gmsrvr|gwsrvr}"
	echo "start_servers_projects.sh restart {authsrvr|gmsrvr|gwsrvr}"
	echo "start_servers_projects.sh {startall|stopall|restartall}"
}

start(){
	case "$srvr_name" in
		authsrvr)
			echo "Starting Authentication Server"
			
			cd ~/dev/repos/Godot4Projects/godot-4-mariadb-multiplayer-tutorial-series/AuthenticationServer
			screen -dmS authsrvr bash -c "$GODOT_BIN --headless --path ./; exec bash"
			;;
		gmsrvr)
			echo "Starting Game Server"
			cd ~/dev/repos/Godot4Projects/godot-4-mariadb-multiplayer-tutorial-series/GameServer
			screen -dmS gmsrvr bash -c "$GODOT_BIN --headless --path ./; exec bash"
			;;
		gwsrvr)
			echo "Starting Gateway Server"
			cd ~/dev/repos/Godot4Projects/godot-4-mariadb-multiplayer-tutorial-series/GatewayServer
			screen -dmS gwsrvr bash -c "$GODOT_BIN --headless --path ./; exec bash"
			;;
		*)
			error=1
			;;
	esac
}

stop() {
    case "$srvr_name" in
        authsrvr|gmsrvr|gwsrvr)
            error=0
            ;;
        *)
            error=1
            ;;
    esac

    if [[ "$error" == 0 ]]; then
        echo "Stopping $srvr_name"
        # Check if there are active screen sessions matching the server name
        sessions="$(screen -ls | grep "\.${srvr_name}")"
        if [[ -n "$sessions" ]]; then
            # Loop through the sessions and stop them
            while IFS= read -r line; do
                screen_session=$(echo "$line" | awk '{print $1}')
                screen -S "$screen_session" -X quit
            done <<< "$sessions"
        # else
        #     echo "No active screen sessions found for $srvr_name"
        fi
    fi
}

#Start-Stop here
case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		stop
		sleep 1
		start
		sleep 1
		;;
	startall)
       for session_name in authsrvr gwsrvr gmsrvr; do
			srvr_name=$session_name
			start
			sleep 1
		done
	    ;;
	stopall)
        for session_name in gwsrvr gmsrvr authsrvr; do
			srvr_name=$session_name
			stop
			sleep 1
		done
	    ;;
	help)
		help
	    ;;
	status)
		echo "status func not completed"
	#   if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
	#   then
	#     echo "$SERVICE is running."
	#   else
	#     echo "$SERVICE is not running."
	#   fi
	  	;;
	restartall)
        for session_name in gwsrvr gmsrvr authsrvr; do
			srvr_name=$session_name
			stop
		done
		
		sleep 1
		
		for session_name in authsrvr gwsrvr gmsrvr; do
			srvr_name=$session_name
			start
		done
		;;
	*)
        error=1
        ;;
esac
if [[ "$error" == 1 ]]; then
	help
fi
exit $error

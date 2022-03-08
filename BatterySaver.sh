#! /system/xbin/bash

# Takser notifications not needed but i recommend it
# https://taskernet.com/shares/?user=AS35m8nUfP1HyOvcmEol9f8eAL6n7JvCG1D06Kyn1G4fLdpZRzMLiZkYTjQoFslhBeR3EIi5VQ%3D%3D&id=Project%3ABatterySaver

# Variables
CONFIG_FILE="config.sh"

# Functions

# Prints the help message
function help {
    banner
    echo "This application lets you set boundaries on how you can charge your phone."
    echo "I need to mention is that this application needs root to function.        "
    echo "HAPPY CHARGING :)                                                         "
    echo "                                                                          "
    echo "Useage:                                                                   "
    echo "    Syntax: BatterySaver [-h|--help|-s|--setup]                           "
    echo "    Options:                                                              "
    echo "        h|help    Prints this message                                     "
    echo "        s|setup   Starts the setup process                                "
    echo "        none      Starts the program as normal and the setup if needed    "
    echo "                                                                          "
    echo "Sidenotes:                                                                "
    echo "    I recommend using this Tasker project for notifications               "
    echo "        link --> bit.ly/35YdckD                                           "
    echo "    I recommend to run it when your phone boots                           "

    # Exits the program
    exit 1
}

# Prints the banner
function banner {
    echo "                                            "
    echo " ______         __   __                     "
    echo "|   __ \.---.-.|  |_|  |_.-----.----.--.--. "
    echo "|   __ <|  _  ||   _|   _|  -__|   _|  |  | "
    echo "|______/|___._||____|____|_____|__| |___  | "
    echo "      _______                       |_____| "
    echo "     |     __|.---.-.--.--.-----.----.      "
    echo "     |__     ||  _  |  |  |  -__|   _|      "
    echo "     |_______||___._|\___/|_____|__|        "
    echo "                               By Staninna  "
    echo "                                            "
}

# Setup proces for the options
function setup {
    banner

    # Stop Charging
    while :; do
        read -p "At what percentage do you want to stop charging: " STOP_CHARGING
        [[ $STOP_CHARGING =~ ^[0-9]+$ ]] || { echo "Enter a valid number please"; continue; }
        if ((STOP_CHARGING > 1 && STOP_CHARGING < 100)); then
            break
        else
            echo "number out of range, please type a number between 1 and 100"
        fi
    done
    echo ""

    # Start Charging
    while :; do
        read -p "At what percentage do you want to start charging again: " START_CHARGING
        [[ $START_CHARGING =~ ^[0-9]+$ ]] || { echo "Enter a valid number please"; continue; }
        if ((START_CHARGING > 1 && START_CHARGING < STOP_CHARGING)); then
            break
        else
            echo "number out of range, please type a number between 1 and $STOP_CHARGING"
        fi
    done
    echo ""

    # Shutdown at
    while :; do
        read -p "At what percentage do you want to shutdown your phone: " SHUTDOWN_AT
        [[ $SHUTDOWN_AT =~ ^[0-9]+$ ]] || { echo "Enter a valid number please"; continue; }
        if ((START_CHARGING >= 0 && SHUTDOWN_AT < START_CHARGING)); then
            break
        else
            echo "number out of range, please type a number between 0 and $START_CHARGING"
        fi
    done
    echo ""

    # Check loop
    while :; do
        read -p "How long does the program needs to wait till checking again (in seconds): " LOOP_TIME
        [[ $LOOP_TIME =~ ^[0-9]+$ ]] || { echo "Enter a valid number please"; continue; }
        if ((LOOP_TIME >= 0 )); then
            break
        else
            echo "number out of range, please type a number above 0"
        fi
    done
    echo ""

    # Write options
    typeset -p STOP_CHARGING START_CHARGING SHUTDOWN_AT LOOP_TIME > $CONFIG_FILE
    echo "Config file saved at $(pwd)/$CONFIG_FILE"

    # Exits the program
    exit 1
}

function isPowered {
    # Getting values
    CHARGING=$(cat /sys/class/power_supply/battery/status)

    if [ $CHARGING == "Charging" ]; then
        echo true
    else
        echo false
    fi
}


# Code

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
elif [[ "$1" == "-s" || "$1" == "--setup" ]]; then
    setup
fi


if [ ! -f $CONFIG_FILE ]; then
    help
fi

. $CONFIG_FILE
LATESTACTION="HENK"
am broadcast -a bash.batterysaver.servicestarted > /dev/null

while true; do

    # Get battery stats
    LEVEL=$(dumpsys battery | grep "level:" | sed "s/level: //" | cut -c 3-)
    POWERED=$(isPowered)

    # Stop charging
    if (( $LEVEL >= $STOP_CHARGING )) && [ ! $LATESTACTION = "Stopped" ]; then
        while [ $POWERED = "true" ]; do
            echo "0" > /sys/class/power_supply/battery/charging_enabled
            POWERED=$(isPowered)
        done
        echo "Stopped charging"
        am broadcast -a bash.batterysaver.stopped > /dev/null
        LATESTACTION="Stopped"

    # Shutdown system
    elif (( $LEVEL <= $SHUTDOWN_AT )) && [ ! $LATESTACTION = "ShutDown" ]; then
        if [ $POWERED = "false" ]; then
            am broadcast -a bash.batterysaver.shutdown > /dev/null
            for i in {1..120}; do
                sleep 1
                POWERED=$(isPowered)
                if [ $POWERED = "true" ]; then
                    am broadcast -a bash.batterysaver.shutdowncancelled > /dev/null
                    break
                fi
            done
            POWERED=$(isPowered)
            if [ $POWERED = "false" ]; then
                setprop sys.powerctl shutdown
            fi
        fi

    # Start charging
    elif (( $LEVEL <= $START_CHARGING )) && [ ! $LATESTACTION = "Started" ]; then
        while [ $POWERED = "false" ]; do
            echo "1" > /sys/class/power_supply/battery/charging_enabled
            POWERED=$(isPowered)
        done
        echo "Started charging"
        am broadcast -a bash.batterysaver.started > /dev/null
        LATESTACTION="Started"
    fi

    sleep $LOOP_TIME
done

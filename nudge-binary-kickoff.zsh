#!/bin/zsh

#############################################\\* Nudge Kickstart *//##############################################
# This script kicks off the respective Nudge binary for supported versions of macOS                              #
#                                                                                                                #
# Display Assertion check provided by Ace Raney - Senior Endpoint Engineer @ ASAPP via MacAdmins Slack (# Nudge) #
# Script Created by Francisco Perez                                                                              #
# Last Modified: 5/28/2021                                                                                       #
#                                                                                                                #
##################################################################################################################

catalina_json=$4
mojave_json=$5

checkForNudge() {

    # Get Logged In User UID
    logged_in_user_uid=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/UserIDKey :/ && ! /loginwindow/ { print $3 }' )

    # Location of Nudge binaries
    nudge_swift_location="/Applications/Utilities/Nudge.app/Contents/MacOS/Nudge"
    nudge_python_location="/Library/nudge/Resources/nudge"

    # Check for Nudge binary
    if [[ -f $nudge_python_location ]] && [[ $(sw_vers -buildVersion) < "20" ]] && [[ $(sw_vers -buildVersion) > "17" ]]; then
      /bin/echo "Python Nudge binary found."

    elif [[ -f $nudge_swift_location ]] && [[ $(sw_vers -buildVersion) > "19" ]]; then
      /bin/echo "Swift Nudge binary found."

    elif [[ ! -f $nudge_python_location ]] && [[ $(sw_vers -buildVersion) < "20" ]] && [[ $(sw_vers -buildVersion) > "17" ]]; then
        /bin/echo "Nudge binary not found. Installing Nudge..."
        /bin/echo "Detected macOS 10.14-10.15. Installing Nudge-Python..."
        /usr/local/bin/jamf policy -event install-nudge-python
        wait
        /bin/sleep 2

    elif [[ $(sw_vers -buildVersion) > "19" ]] && [[ ! -f $nudge_swift_location ]]; then
        /bin/echo "Nudge binary not found. Installing Nudge..."
        /bin/echo "Detected macOS 11 or newer. Installing Nudge (Swift)..."
        /usr/local/bin/jamf policy -event install-nudge-swift
        wait
        /bin/sleep 2

    fi

    # Verify ONLY correct Nudge installed
    if [[ -f $nudge_python_location ]] && [[ $(uname -r | cut -d '.' -f 1) > "19" ]]; then
        /bin/echo "Wrong version of Nudge detected - deleting..."

        # Unload LaunchAgent
        echo "Unloading com.erikng.nudge.plist LaunchAgent..."
        /bin/launchctl stop /Library/LaunchAgents/com.erikng.nudge.plist
        /bin/launchctl bootout gui/"${logged_in_user_uid}" /Library/LaunchAgents/com.erikng.nudge.plist
        /bin/launchctl remove /Library/LaunchAgents/com.erikng.nudge.plist

        # Kill Nudge just in case (say someone manually opens it and not launched via launchagent
        echo "Killing Nudge-Python..."
        killall Nudge

        # Remove Nudge Files
        echo "Deleting Nudge-Python..."
        /bin/rm /Library/LaunchAgents/com.erikng.nudge.plist
        /bin/rm -fdr /Library/nudge

        echo "Nudge-Python deleted."

    elif [[ -f $nudge_swift_location ]] && [[ $(uname -r | cut -d '.' -f 1) < "20" ]] && [[ $(sw_vers -buildVersion) > "17" ]]; then
        /bin/echo "Wrong version of Nudge detected - deleting..."

        # Unload LaunchAgent
        echo "Unloading com.github.macadmins.Nudge.plist LaunchAgent..."
        /bin/launchctl stop /Library/LaunchAgents/com.github.macadmins.Nudge.plist
        /bin/launchctl bootout gui/"${logged_in_user_uid}" /Library/LaunchAgents/com.github.macadmins.Nudge.plist
        /bin/launchctl remove /Library/LaunchAgents/com.github.macadmins.Nudge.plist

        # Kill Nudge just in case (say someone manually opens it and not launched via launchagent
        echo "Killing Nudge (Swift)..."
        killall Nudge

        # Remove Nudge Files
        echo "Deleting Nudge (Swift)..."
        /bin/rm /Library/LaunchAgents/com.github.macadmins.Nudge.plist
        /bin/rm -rf /Applications/Utilities/Nudge.app
        /usr/sbin/pkgutil --pkgs | /usr/bin/grep -i "Nudge.app" | /usr/bin/xargs /usr/bin/sudo /usr/sbin/pkgutil --forget

        echo "Nudge (Swift) deleted."

    fi

}

checkForOldJsonConfig() {
    #Location of Old JSON
    nudge_json_location="/Library/nudge/Resources/nudge.json"

    # Check for existing nudge.json - delete if found
    if [[ $(sw_vers -buildVersion) < "20" ]] && [[ ! -f $nudge_json_location ]]; then
        /bin/echo "No nudge.json file found."

    elif [[ $(sw_vers -buildVersion) < "20" ]] && [[ -f $nudge_json_location ]]; then
      /bin/rm -Rf $nudge_json_location

    else
      /bin/echo "Nudge JSON check not applicable. Moving on..."

    fi
}


# Check for Display Assertions
checkForDisplaySleepAssertions() {
    Assertions="$(/usr/bin/pmset -g assertions | /usr/bin/awk '/NoDisplaySleepAssertion | PreventUserIdleDisplaySleep/ && match($0,/\(.+\)/) && ! /coreaudiod/ {gsub(/^\ +/,"",$0); print};')"
    # There are multiple types of power assertions an app can assert.
    # These specifically tend to be used when an app wants to try and prevent the OS from going to display sleep.
    # Scenarios where an app may not want to have the display going to sleep include, but are not limited to:
    #   Presentation (KeyNote, PowerPoint)
    #   Web conference software (Zoom, Webex)
    #   Screen sharing session
    # Apps have to make the assertion and therefore it's possible some apps may not get captured.
    # Some assertions can be found here: https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiontypes
    while [[ "$Assertions" ]]; do
        echo "$Assertions"
        #sleep 1800
        sleep 60
        Assertions="$(/usr/bin/pmset -g assertions | /usr/bin/awk '/NoDisplaySleepAssertion | PreventUserIdleDisplaySleep/ && match($0,/\(.+\)/) && ! /coreaudiod/ {gsub(/^\ +/,"",$0); print};')"
    done
}


# Check macOS version and kickoff appropriate binary
runNudgeBinary() {
    if [[ $(sw_vers -buildVersion) > "20" ]] && [[ $(sw_vers -buildVersion) < "21" ]]; then
      echo "macOS version: macOS Big Sur (11)"
      echo "Kicking off Nudge..."
      /Applications/Utilities/Nudge.app/Contents/MacOS/Nudge

    elif [[ $(sw_vers -buildVersion) > "19" ]] && [[ $(sw_vers -buildVersion) < "20" ]]; then
      echo "macOS version: macOS Catalina (10.15)"
      echo "Kicking off Nudge..."
      /Library/nudge/Resources/nudge --jsonurl=$catalina_json

    elif [[ $(sw_vers -buildVersion) > "18" ]] && [[ $(sw_vers -buildVersion) < "19" ]]; then
      echo "macOS version: macOS Mojave (10.14)"
      echo "Kicking off Nudge..."
      /Library/nudge/Resources/nudge --jsonurl=$mojave_json

    else
      echo "macOS version: Unsupported macOS/OSX version"
      echo "Exiting..."
      exit 1

    fi
}

# Do Stuff
checkForNudge
checkForOldJsonConfig
checkForDisplaySleepAssertions
runNudgeBinary

exit 0

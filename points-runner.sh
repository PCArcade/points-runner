#!/bin/bash
# Gimme-the-points runner

AUTORERUN="yes" #change to "yes" if you want the script to rerun on fail
EMAIL="pcarcade@gmail.com" # Set your email address here, leave blank to not send
DATE=$(date +%F)
SUCCESS=0
INCOMPLETES=0
LOCATION="/home/pcarcade/gimme-the-points" # Change this to the LOCATION gimme the points is installed in
ACCOUNTS=$(cat "$LOCATION/accounts.json" | grep '",' -c) # how many accounts are we running for?
RERUN=$"/home/pcarcade/points-runner/points-runner.sh" # set to $LOCATION if this script is in the same place as gimme-the-points or the full path including filename if not
STATS=$"$LOCATION/stats.json"
ERRFILE=$"$LOCATION/error.log"

# cat $STATS | mail -A $STATS -s "looping error stats emailed" $EMAIL && exit #uncomment this line and save whilst script is running if the cronjob is running constantly

cd $LOCATION

#Clean up from previous day

if [ -f "$ERRFILE" ]
then
        mv -f $ERRFILE $LOCATION/logs/error$DATE.log
fi

if [ -f "$STATS" ]
then
        mv -f $STATS $LOCATION/logs/stats$DATE.json
fi

#npm install - #needed if config.json has changed
npm update #if config.json NOT changed use this one
npm start #Run the script

#--------------------------------------------------------------------------------------------------------------------------
# Everything below checks for the successful running of the script
#--------------------------------------------------------------------------------------------------------------------------

ACCOUNTSRAN=$(cat $STATS | grep '"last_ran"' -c) #find out how many accounts the scipt ran for
if [ $ACCOUNTSRAN == $ACCOUNTS ] #check that the script ran for all accounts if so do this block below
then
	for d in `cat $STATS | grep '"last_ran"' | sed 's/^.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*$/\1/'`
	do
		if
			[ $d == $DATE ]
		then
       		let SUCCESS=SUCCESS+1 #add to successful run count where the run date for each account is today's date
		fi
	done
     	if
		[ $SUCCESS == $ACCOUNTSRAN ] #check that all accounts ran successfully , if so check for no incomplete dashboard tasks
	then
		for i in `cat $STATS | grep '"incomplete_tasks"' | grep -oE '[0-9.]+'`
		do
			let INCOMPLETES=INCOMPLETES+$i
		done
	else
		if
			[ "$EMAIL" != "" ]
		then
			cat $STATS | mail -A $STATS -s "Gimme the Points - not all accounts ran successfully re-running" $EMAIL # notifies if not all accounts ran and attaches stats to see which
		else
			echo "Gimme the Points - not all accounts ran successfully - check logs"
		fi
		if
			[ $AUTORERUN == "yes" ]
		then
			$RERUN
		fi
	fi
	if
		[ $INCOMPLETES = 0 ] # if there are no incomplete  tasks email the stats file to the email address specified
	then
#--------------------------------------------------------------------------------------------------------------------
#                                       check for missing searches
#--------------------------------------------------------------------------------------------------------------------
		DESKTOTAL=$(cat $STATS | grep "desktop" | grep -oP '^\D*\d+\D*\K\d+' | head -1)
		for i in $(cat $STATS | grep "desktop" | grep -o -E '[0-9]+ ')
	        do
        	        let DESKTOP=DESKTOP+$i
	        done
		DESK=$(($DESKTOP / $DESKTOTAL))
		if
		        [ $DESK != $ACCOUNTS ]
		then
		        let ERROR=ERROR+1
		fi
		MOBTOTAL=$(cat $STATS | grep "mobile" | grep -oP '^\D*\d+\D*\K\d+' | head -1)
		for i in $(cat $STATS | grep "mobile" | grep -o -E '[0-9]+ ')
	        do
	                let MOBILE=MOBILE+$i
	        done
		MOB=$(($MOBILE / $MOBTOTAL))
		if
		        [ $MOB != $ACCOUNTS ]
		then
		        let ERROR=ERROR+1
		fi
		if
		        [ "$ERROR" != "" ]
		then
		        if
                               [ "$EMAIL" != "" ]
                        then
				cat $STATS | mail -A $STATS -s "Gimme the points - problem in searches please see attached stats" $EMAIL # notify of search fail
                        else
                                echo "Error in searches"
			fi
			if
               	                [ $AUTORERUN == "yes" ]
                        then
       	                        $RERUN
                       	fi
		else
#---------------------------------------------------------------------------------------------------------------------
#                                              search check end
#---------------------------------------------------------------------------------------------------------------------
		if
			[ "$EMAIL" != "" ]
		then
			cat $STATS | mail -A $STATS -s "Gimme the Points has succeeded - stats attached" $EMAIL # notify of success
		else
			echo "Gimme the Points has succeeded"
		fi
		fi
	else
		if
			[ $EMAIL!="" ]
		then
			cat $STATS | mail -A $STATS -s "Dashboard tasks incomplete, check attached stats file" $EMAIL # notify of incomplete tasks and attaches stats to see which
		else
			echo "Dashboard tasks incomplete - check logs"
		fi
		if
				[ $AUTORERUN == "yes" ]
		then
			$RERUN
		fi
	fi
else
	if
        	[ $EMAIL!="" ]
        then
		cat $STATS | mail -A $STATS -s "Accounts ran vs Account number is different, check attached stats file" $EMAIL #notify of accounts not being run and attaches stats to see which
	else
		echo "Accounts ran vs Account number is different - check logs"
	fi
	if
		[ $AUTORERUN == "yes" ]
	then
		$RERUN
	fi
fi


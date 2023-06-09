#!/bin/bash

#-------------------------------------------------------------
#           Microsoft rewards bot runner script
#-------------------------------------------------------------

AUTORERUN="yes" # yes or no depending on whether you want the scrip to re run on fail
EMAIL="" # Set your email address here, leave blank to not send
DATE=$(date +%F) # Get today's date in YYYY-MM-DD formate
LOCATION="/home/user/gimme-the-points" # Change this to the LOCATION gimme the points is installed in
ACCOUNTS=$(cat "$LOCATION/accounts.json" | grep '",' -c) # how many accounts are we running for?
STATS=$"$LOCATION/stats.json"
ERRFILE=$"$LOCATION/error.log"
LOOPS=3 # Number of times to loop on error (recommended is 3 as this should clear all the errors that are likely to be able to be cleared)
declare -i COUNT=0 # limits the amout of times the script will loop
CLEANUP="no" # Remove previous log files or not "yes" renames stats.json and error.log with today's date appended 

cd $LOCATION

#Clean up from previous day
if [ $CLEANUP == "yes" ]
then
	if [ -f "$ERRFILE" ]
	then
        	mv -f $ERRFILE $LOCATION/logs/error$DATE.log
	fi
	if [ -f "$STATS" ]
	then
        	mv -f $STATS $LOCATION/logs/stats$DATE.json
	fi
fi
#Update gimme the points and components
git -C $lOCATION pull
npm update

loop()
{
if [ $COUNT -lt $LOOPS ]
then
	npm start #Run the script

#--------------------------------------------------------------------------------------------------------------------------
# Everything below checks for the successful running of the script
# Starting with handling of the error.log file if it exists 
#--------------------------------------------------------------------------------------------------------------------------

	if [ -f "$ERRFILE" ] # Does an error file exist
	then
	        ERRSIZE=$(du -sb $ERRFILE | awk '{ print $1 }') # if yes, set ERRSIZE to the size (in Bytes) of the file
	else
	        ERRSIZE=0 # if no set ERRSIZE to 0
	fi
	if [ $ERRSIZE -gt 0 ] #check that the file is not blank (0 siz0)
	then
		if
			[ "$EMAIL" != "" ] #if $EMAIL Variable is populated sent fail message and rerun
		then
			cat $ERRFILE | mail -A $ERRFILE -A $STATS -s "Gimme the Points has failed check attached logs" $EMAIL # notifies of errors and attaches error log
		else
			echo "Gimme the Points has failed check logs"
		fi
		if
        		[ $AUTORERUN == "yes" ]
	        then
			unset ERRSIZE
			((COUNT++))
        	        loop
	        fi
#-----------------------------------------------------------------------------------------------------------------------------------
# If error.log is ok, the below checks the amount of accounts that completed is the same as the number of accounts in accounts.json
#-----------------------------------------------------------------------------------------------------------------------------------

	else
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
					echo "Gimme the Points - not all accounts ran successfully - check logs success=$SUCCESS and accountran=$ACCOUNTSRAN, Incompletes=$INCOMPLETES"
				fi
				if
					[ $AUTORERUN == "yes" ]
				then
					unset SUCCESS
					unset INCOMPLETES
					((COUNT++))
					loop
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
						unset ERROR
						unset SUCCESS
						((COUNT++))
	        	                        loop
	                        	fi
				else
#--------------------------------------------------------------------------------------------------------------------------------
# Below is if no errors are encoutered to this point, does one last check for dashboard tasks and searhes being incomplete
# sends success message if they are or Incomplete message detailing which is wrong if not
#--------------------------------------------------------------------------------------------------------------------------------
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
					[ "$EMAIL" != "" ]
				then
					cat $STATS | mail -A $STATS -s "Dashboard tasks incomplete, check attached stats file" $EMAIL # notify of incomplete tasks and attaches stats to see which
				else
					echo "Dashboard tasks incomplete - check logs"
				fi
				if
					[ $AUTORERUN == "yes" ]
				then
					unset SUCCESS
					((COUNT++))
					loop
				fi
			fi
		else
			if
		        	[ "$EMAIL" != "" ]
		        then
				cat $STATS | mail -A $STATS -s "Accounts ran vs Account number is different, check attached stats file" $EMAIL #notify of accounts not being run and attaches stats to see which
			else
				echo "Accounts ran vs Account number is different - check logs"
			fi
			if
				[ $AUTORERUN == "yes" ]
			then
				((COUNT++))
				loop
			fi
		fi
	fi
fi
}
loop

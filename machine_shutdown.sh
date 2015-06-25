#!/bin/bash

unset $root

flagcheck()
{
        if [ ! -z $1 ];
        then
                shflag="0"
        fi
        if [ -z $shflag ];
        then
                echo "No shutdown flag is set."
                exit 0
        else
                case $shflag in
                        0)
                                echo "Shutdown flag is set to 0. That means it was cleared."
                                echo -e "$now $HOSTNAME Setting shutdown flag to 0. (NEUTRAL)" >> /var/log/shutdown.log
                                proceed
                        ;;
                        1)
                                echo "Shutdown flag is set to 1. That means this server is going to be shutted down."
                                echo -e "$now $HOSTNAME Setting shutdown flag to 1 (SHUTDOWN)." >> /var/log/shutdown.log
                                proceed
                                shutdown -h now
                        ;;
                        2)
                                echo "Shutdown flag is set to 2. That means this server is going to be rebooted."
                                echo -e "$now $HOSTNAME Setting shutdown flag to 2 (REBOOT)." >> /var/log/shutdown.log
                                proceed
                                shutdown -r now
                        ;;
                        *)
                                echo "Shutdown flag is set to $shflag. This is invalid setting and the flag will be cleared now and set to \"0\""
                                echo -e "$now $HOSTNAME Wrong argument passed ($shflag). Setting shutdown flag to 0." >> /var/log/shutdown.log
                                export MACHINE_SHUTDOWN="0"
                                shflag="0"
                                proceed
                        ;;
                esac
        fi

}

areuroot()
{
        if [ "$UID" -eq 0 ] && [ "$USER" == "root" ];
        then
                root="1"
        else
                echo "You are not root. This script must be executed as root user."
        fi
}

proceed()
{
        echo "SHFLAG: " $shflag
        unset MACHINE_SHUTDOWN
        grep MACHINE_SHUTDOWN $bashrc > /dev/null
        if [ $? -eq 0 ];
        then
                tempfile=`mktemp /tmp/tmp-XXXXXX`
                grep -v MACHINE_SHUTDOWN $bashrc > $tempfile
                cat $tempfile > $bashrc
                echo "export MACHINE_SHUTDOWN=$shflag" >> $bashrc
                . /root/.bashrc
        else
                echo "export MACHINE_SHUTDOWN=$shflag" >> $bashrc
                . /root/.bashrc
        fi
        rm -fr $tempfile
        return 0
}

cronaction()
{
        case $MACHINE_SHUTDOWN in
                0)
                        echo -e "$now $HOSTNAME DOING NOTHING" >> /var/log/shutdown.log
                ;;
                1)
                        echo "$now $HOSTNAME MACHINE SHUTDOWN BY 'shutdown -t now'" >> /var/log/shutdown.log
                        flagcheck "0"
                        ## Here is the right place the exact shutdown command
                ;;
                2)
                        echo "$now $HOSTNAME MACHINE REBOOT BY 'reboot'" >> /var/log/shutdown.log
                        flagcheck "0"
                        ## Here is the right place the exact roboot command
                ;;
                *)
                        echo "$now $HOSTNAME WRONG ENV VARIABLE SET. RESETTING TO 0." >> /var/log/shutdown.log
                        flagcheck "0"
                ;;
        esac
}

cronsetup()
{
        if [ -z `crontab -l | grep machine.shutdown | awk '{print $1}'` ];
        then
                tempfile=`mktemp /tmp/tmp-CCXXXXX`
                crontab -l | grep -v "no crontab for" > $tempfile
                echo "*/1 * * * * . /root/.bashrc && /usr/local/bin/machine_shutdown.sh croncheck" >> $tempfile
                crontab $tempfile
                rm -fr $tempfile
        else
                echo "Cronjob for machine shutdown is present in root's crontab."
                crontab -l
                cronaction
        fi
}

croncheck()
{
        if [ $crflag == "croncheck" ];
        then
                echo "Argument is set to check the cron jobs"
                cronsetup
        else
                echo "Wrong argument has been given."
                exit 1
        fi
}

source /root/.bashrc
now=`date "+%d-%m-%Y %H:%M:%S %z"`
logfile="/var/log/shutdown.log"
bashrc="/root/.bashrc"
flag="$1"
areuroot
if [ "$root" -eq "1" ];
then
        if [ -z $flag ];
        then
                echo "No argument has been given. This will not work."
                exit 1
        else
                case $flag in
                        [0-9])
                                shflag="$flag"
                                flagcheck
                        ;;
                        croncheck)
                                crflag="$flag"
                                croncheck
                        ;;
                        *)
                                echo "Wrong argument has been given."
                                exit 0
                        ;;
                esac
        fi
else
        echo "You are not root. This script must be executed as root user."
fi

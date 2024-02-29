## virtual_archlinux_minimal_bios/super.sh - v2.2.1
##
## This script is just an wrapper that executes other scripts in serie, covering
## most of the installation steps. Also, these instalations is customized to
## work better in a virtual machine, do not use it to install in your own
## computer without changing the logic of each routine.
##
## In the future, this script will also cover the root and user post install
## setup, everything will become full automatic.
##
## Arguments:
##  -h --help                   Shows this help message.
##  -d --dry                    Execute all routines but all commands will have the --dry flag too.
##  -c --curl [curl_root]       curl address that this and other scripts will use to fetch the dependencies.
##  -s --skip [routine]         Skip the specifyed setup/installation routine;
##                                  Can be either "fdisk", "pacstrap" or "chroot".
##  -t --timezone [timezone]    Timezone that this script will set, default is "America/Sao_Paulo"
##  -k --keymap [keymap]        Keyboard layout for the instalation, default is "br-abnt2"
##
## Routines:
##  This super script is responsible to run a list of other scripts that I like
##  to call them 'routines', each routine does a specific thing, and you can
##  skip one or more of them.
##      1. fdisk:       Uses fdisk scripts to format and mount 3 partitions (boot, swap & btrfs).
##      2. pacstrap:    Install the base packages and setup pacman.conf and fstab.
##      3. chroot:      Will change to /mnt and finish the setup with grub, sudo, users, etc.

OPTIONS="hdc:s:t:k:"
LONG_OPTIONS="help,dry,curl:,skip:,timezone:,keymap:"
ARGS=$(getopt --options "${OPTIONS}" --longoptions "${LONG_OPTIONS}" --name "${0}" -- "${@}")

if [ $? -ne 0 ]
then
    printf "\n\nError: Invalid argument string, use ${0} --help for the command usage\n\n"
    exit $?
fi

eval "set -- ${ARGS}"
unset OPTIONS LONG_OPTIONS ARGS


#@ PARSING ARGUMENTS -----------------------------------------------------------

curl_root=""
dry_flag=""
timezone="America/Sao_Paulo"
keymap="br-abnt2"
skip_fdisk=0;  skip_pacstrap=0;  skip_chroot=0;

#note: To add more routines, the devolper should (1) update the skip flags, (2)
#      update the "-s" or "--skip" case in the argument parser and (3) update
#      version of this script. After all that, you can play with this new
#      routine at the script body... :v

while true
do
    case "${1}" in
        "-c" | "--curl")      curl_root="${2}";  shift 2 ;;
        "-d" | "--dry")       dry_flag="--dry";  shift   ;;
        "-t" | "--timezone")  timezone="${2}";   shift 2 ;;
        "-k" | "--keymap")    keymap="${2}";     shift 2 ;;

        "-h" | "--help")
            grep --color="never" '^## *' "${BASH_SOURCE}" |
                sed 's/^## \?//'
            exit
        ;;

        "-s" | "--skip")
            case "${2}" in
                "fdisk")     skip_fdisk=1    ;;
                "pacstrap")  skip_pacstrap=1 ;;
                "chroot")    skip_chroot=1   ;;
            esac
            shift 2
        ;;

        "--") shift;  break ;;
    esac
done


#@ GLOBAL CONSTANTS ------------------------------------------------------------

SUPER="virtual_archlinux_minimal_bios"


#@ FETCHING DEPENDENCIES -------------------------------------------------------

if [ -z "${curl_root}" ]
then
    printf "\n\nError: You need to specify a curl root to fetch the other scripts\n\n"
    exit 1
fi

curl "${curl_root}/include/runn.sh" -so "runn.sh" && . runn.sh || exit 2


#@ UTILITY FUNCTIONS -----------------------------------------------------------

function execute_setup_routine {
    local routine_name="${1}";  shift
    local user_flags="${@}"
    local skip="skip_${routine_name}"

    if [ "${!skip}" -eq 1 ]  #check for the global skip variable for each specific command ($1 argument)
    then
        printf "\nWarning: Skiping the %s setup routine!\n" "${routine_name}"
        return 0
    fi

    if [ "${routine_name}" = "chroot" ]  #the chroot script should be executed with a scaped command string!
    then
        local S_CHROOT="curl '${curl_root}/${SUPER}/source/${routine_name}.sh' -so '${routine_name}.sh' &&
                            bash ${routine_name}.sh --curl ${curl_root} ${user_flags}"
        echo -e "${S_CHROOT}\nexit\n" |
            arch-chroot /mnt
    else
        curl "${curl_root}/${SUPER}/source/${routine_name}.sh" -so "${routine_name}.sh" &&
            eval -- "bash ${routine_name}.sh --curl ${curl_root} ${user_flags}"
    fi
}


#@ SCRIPT BODY -----------------------------------------------------------------

clear
printf -- "\n\n"
printf -- "Info: This script is meant to be running inside an Arch Linux live ISO\n"
printf -- "environment, also, it was created to setup a specific kind of virtual\n"
printf -- "machine (do not run this on your real hardware without checking what it\n"
printf -- "does first): A BIOS system with a /boot partition, a swap -- both 512MB\n"
printf -- "-- and a BTRFS partition with a @ subvolume for the / and @home for the\n"
printf -- "/home. Hope it works just fine for you and good luck!\n"
printf -- "\n\n"
read -sn1

runn --ignore "loadkeys ${keymap}"
runn --ignore "timedatectl --set-timezone ${timezone}"

execute_setup_routine "fdisk"    "${dry_flag}"
execute_setup_routine "pacstrap" "${dry_flag}"
execute_setup_routine "chroot"   "${dry_flag}"
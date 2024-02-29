#note: It's important that this script can skip some parts depending of some argument values


clear
printf "\n\n"
printf "Info: ...\n"  #todo: add a description for this script (useful at run time)
printf "\n\n"
read -sn1


## virtual_archlinux_minimal_bios/super.sh - v0.1.0
##
## ... #todo: add a good helper description (useful for debug)
##
## Routines:
##  This super script is responsible to run a list of other scripts that I like
##  to call them 'routines', each routine does a specific thing, and you can
##  skip one or more of them.
##      1. fdisk: ...  #todo: add a description for each routine
##
## Arguments:
##  -h --help           Shows this help message.
##  -s --skip [routine] Skip the specifyed setup/installation routine;
##                          Can be either "fdisk", "pacstrap" or "chroot".

OPTIONS="hdc:s:"
LONG_OPTIONS="help,dry,curl:,skip:"
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
is_dry=0
skip_fdisk=0;  skip_pacstrap=0;  skip_chroot=0;

#note: To add more routines, the devolper should (1) update the skip flags, (2)
#      update the "-s" or "--skip" case in the argument parser and (3) update
#      version of this script. After all that, you can play with this new
#      routine at the script body... :v

while true
do
    case "${1}" in
        "-c" | "--curl")  curl_root="${2}";  shift 2  ;;
        "-d" | "--dry")   is_dry=1;          shift    ;;

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

curl "${curl_root}/include/exec.sh" -so "exec.sh" && . exec.sh


#@ UTILITY FUNCTIONS -----------------------------------------------------------

function execute_setup_routine {
    local routine_name="${1}"
    local skip="skip_${routine_name}"

    if [ "${!skip}" -eq 1 ]
    then
        printf "\nWarning: Skiping the %s setup routine!\n" "${routine_name}"
        return 0
    fi

    printf "\nDebug: Executing the %s setup routine!\n" "${routine_name}"

    [ $is_dry -eq 1 ] &&
        return 0

    if [ "${routine_name}" = "chroot" ]  #the chroot script should be executed with a scaped command string!
    then
        local S_CHROOT="curl '${curl_root}/${SUPER}/source/${routine_name}.sh' -so '${routine_name}.sh' &&
                            bash ${routine_name}.sh"
        echo -e "${S_CHROOT}\nexit\n" |
            arch-chroot /mnt
    else
        curl "${curl_root}/${SUPER}/source/${routine_name}.sh" -so "${routine_name}.sh" &&
            bash "${routine_name}.sh"
    fi
}


#@ SCRIPT BODY -----------------------------------------------------------------

execute_setup_routine "fdisk"
execute_setup_routine "pacstrap"
execute_setup_routine "chroot"  #todo: this function should accept custom arguments from here
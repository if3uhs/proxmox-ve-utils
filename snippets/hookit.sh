#!/bin/bash
VMID="${1:-unknow}"
PHASE="${2:-unknow}"

VM_CONF="/etc/pve/nodes/${HOSTNAME}/qemu-server/${VMID}.conf"

HK_VERSION="1.0"
HK_MSG="false"

vmpid() {
    cat "/var/run/qemu-server/${VMID}.pid" 2>/dev/null
}

hk_msg(){
    [ $HK_MSG == "true" ] && echo "${FUNCNAME[1]}:" "$@"
}

hk_eval() {
    [ $HK_MSG == "true" ] && echo "${FUNCNAME[1]}:" "$@"
    eval "$@"
}

hk_exit() {
    echo "hk_exit(${1}):" "${FUNCNAME[1]}:" "${@:2}"
    exit $1
}

hk_exit_by_not_exist() {
    [ -e "$1" ] || hk_exit 200 "${FUNCNAME[1]}:" "$1" "${@:2}"
}

hk_open_msg() {
    [ -z "$(cat $VM_CONF | grep '#+ hk_msg')" ] || HK_MSG="true"
}

hk_vmconf_option_exist() {
    [ -z "$1" ] && return 1
    [ -n "$(cat $VM_CONF | grep "${1}:")" ] || return 1
}

hk_vmconf_get_value() {
  local vm_option="$1"
  local key="$2" 
  cat $VM_CONF | grep "${vm_option}:" | sed 's/,/ /g' | sed "s/.*${key}=//; s/ .*//"
}

hk_valid_bridge_nic() {
    local bridge="$1"
    local nic="$2"

    local res=$(brctl show "$bridge" 2>/dev/null | grep "$nic")
    local res_code=$?
    [ $res_code -eq 0 ] || return $res_code

    [ -z "$res" ] && return 1
    return 0
}

hk_vmconf_get_macaddr() {
    local vm_option="$1"
    local bridge="$2"     
    cat $VM_CONF | grep "${vm_option}:" | grep "bridge=${bridge}" | sed -r 's/.*=(.*),bridge.*/\1/' 
}

hk_vmconf_get_pci_ids() {
  local vm_option="$1"
  cat $VM_CONF | grep "${vm_option}:" | awk '{print $2}' | awk -F, '{print $1}'
}

hk_pfbridge() {
    # check args
    hk_vmconf_option_exist "$1" || hk_exit 201 "vmconf option(${1:-null}) not exist"
    local vm_option="$1"

    [ -z "$2" ] && hk_exit 202 "invalid nic($nic)"
    local nic="$2"

    #
    local op="null"
    [ "$PHASE" == "pre-start" ] && op="add"
    [ "$PHASE" == "post-stop" ] && op="del"
    [ "$op" == "null" ] && return 0

    local pfbridge="$(hk_vmconf_get_value ${vm_option} "bridge")"
    [ -z "$pfbridge" ] && hk_msg "get pfbridge in vm_option($vm_option) failed" && return

    hk_valid_bridge_nic $pfbridge $nic
    [ $? -ne 0 ] && hk_msg "nic($nic) not in pfbridge($pfbridge)" && return

    local mac_addr="$(hk_vmconf_get_macaddr $vm_option $pfbridge)"
    [ -z "$mac_addr" ] && hk_msg "get mac_addr in vm_option($vm_option).bridge($pfbridge) failed" && return

    # debug output
    # hk_msg "vm_option=$vm_option" "nic=$nic" "pfbridge=$pfbridge" "mac_addr=$mac_addr"

    local exist="$(bridge fdb | grep -i "${mac_addr}" | grep -i "${nic}")"
    local need_op="false"

    if [ "$op" == "add" ]; then
        [ -n "${exist}" ] || need_op="true"
    elif [ "$op" == "del" ]; then
        [ -z "${exist}" ] || need_op="true"
    fi

    local e="bridge fdb ${op} ${mac_addr} dev ${nic}"
    [ "$need_op" == "true" ] && hk_eval $e
}

hk_gpu() {
    # check args
    hk_vmconf_option_exist "$1" || hk_exit 201 "vmconf option(${1:-null}) not exist"
    local vm_option="$1"

    #
    local op="null"
    [ "$PHASE" == "pre-start" ] && op="bind"
    [ "$PHASE" == "post-stop" ] && op="reset"
    [ "$op" == "null" ] && return 0

    # check iommu?
    [ -d "/sys/class/iommu" ]
    [ $? -ne 0 ] && hk_msg "do you need to enable iommu?" && return

    # getopt
    local args=$(getopt -o av: -l all,vendor: -- ${@:2})
    [ $? -ne 0 ] && hk_msg "getopt($?)" && return
    eval set -- "$args"
    while true; do
        case "$1" in
            -a | --all)                     all="true";shift;;
            -v | --vendor)                  vendor="$2";shift 2;;
            --)                             shift;break;;
        esac
    done
    [ -z "$all" ] && all="false"
    [ -z "$vendor" ] && hk_exit 202 "invalid vendor($vendor)" 
    case "$vendor" in
        "nvidia") ;;
        "intel")
            hk_msg "not test vendor($vendor)"
            ;;
        *)
          hk_msg "not support vendor($vendor)"
          return;;
    esac

    #
    local pci_ids="$(hk_vmconf_get_pci_ids $vm_option)"
    [ -z "$pci_ids" ] && hk_msg "get pci_ids in vm_option($vm_option) failed" && return
    pci_ids="${pci_ids}.0"
    
    # debug output    
    # hk_msg "-all=$all" "vendor=$vendor" "pci_ids=$pci_ids"

    for dev in $(ls /sys/bus/pci/devices/${pci_ids}/iommu_group/devices); do
        if [ "$op" == "bind" ]; then
            local override="echo vfio-pci > /sys/bus/pci/devices/${dev}/driver_override"
            hk_eval $override
        elif [ "$op" == "reset" ]; then
            local reset_driver="null"
            local reset_count="$(echo $dev | cut -d "." -f2)"
            case "$vendor" in
                "nvidia")
                    [ "$reset_count" == "0" ] && reset_driver="nouveau"
                    [ "$reset_count" == "1" ] && reset_driver="snd_hda_intel"                
                    [ "$reset_count" == "2" ] && reset_driver="xhci_hcd"   
                    [ "$reset_count" == "3" ] && reset_driver="nvidia-gpu"                 
                    ;;
                "amd")
                    # todo
                    return
                    ;;
                "intel")
                    # no test
                    [ "$reset_count" == "0" ] && reset_driver="i915"
                    [ "$reset_count" == "1" ] && reset_driver="snd_hda_intel"                
                    [ "$reset_count" == "2" ] && reset_driver="xhci_hcd"      
            esac
            local unbind="echo $dev > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null"
            hk_eval $unbind

            local override="echo ${reset_driver} > /sys/bus/pci/devices/${dev}/driver_override"
            hk_eval $override

            local probe="echo $dev > /sys/bus/pci/drivers_probe"
            hk_eval $probe

            [[ "$vendor" == "nvidia" && "$reset_count" == "3" ]] && break       
            [[ "$vendor" == "intel" && "$reset_count" == "2" ]] && break
        fi

        [ "$all" != "true" ] && break
    done
}

hk_cmds() {
    case "$1" in
      "hk_msg")
        ;;

      "hk_pfbridge")
        hk_pfbridge "$2" "$3"
        ;;

      "hk_gpu")
        hk_gpu "$2" "${@:3}"
        ;;

      *)
        hk_msg "unknown option '$1' "
        ;;
    esac
}

hk_main() {
    echo "hookit verion $HK_VERSION"
    [ $VMID == "unknow" ] && hk_exit 0 "vmid=unknow"
    [ $PHASE == "unknow" ] && hk_exit 0 "phase=unknow"
    hk_exit_by_not_exist "$VM_CONF" && hk_open_msg

    while read flag cmds; do
        case "$flag" in
        "#+")
            hk_cmds $cmds
            ;;

        *)
            ;;
        esac
    done < $VM_CONF
}

hk_main

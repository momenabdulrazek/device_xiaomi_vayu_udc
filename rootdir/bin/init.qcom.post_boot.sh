#! /vendor/bin/sh

# Copyright (c) 2012-2013, 2016-2020, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

target=`getprop ro.board.platform`

function configure_memory_parameters() {
    # Set Memory parameters.
    #
    # Set per_process_reclaim tuning parameters
    # All targets will use vmpressure range 50-70,
    # All targets will use 512 pages swap size.
    #
    # Set Low memory killer minfree parameters
    # 32 bit Non-Go, all memory configurations will use 15K series
    # 32 bit Go, all memory configurations will use uLMK + Memcg
    # 64 bit will use Google default LMK series.
    #
    # Set ALMK parameters (usually above the highest minfree values)
    # vmpressure_file_min threshold is always set slightly higher
    # than LMK minfree's last bin value for all targets. It is calculated as
    # vmpressure_file_min = (last bin - second last bin ) + last bin
    #
    # Set allocstall_threshold to 0 for all targets.
    #

    echo 0 > /proc/sys/vm/page-cluster
    echo 100 > /proc/sys/vm/swappiness
}

case "$target" in
    "msmnile")
    # Core control parameters for gold
    echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
    echo 30 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
    echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
    echo 3 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

    # Core control parameters for gold+
    echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
    echo 60 > /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
    echo 30 > /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
    echo 100 > /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms
    echo 1 > /sys/devices/system/cpu/cpu7/core_ctl/task_thres
    # Controls how many more tasks should be eligible to run on gold CPUs
    # w.r.t number of gold CPUs available to trigger assist (max number of
    # tasks eligible to run on previous cluster minus number of CPUs in
    # the previous cluster).
    #
    # Setting to 1 by default which means there should be at least
    # 4 tasks eligible to run on gold cluster (tasks running on gold cores
    # plus misfit tasks on silver cores) to trigger assitance from gold+.
    echo 1 > /sys/devices/system/cpu/cpu7/core_ctl/nr_prev_assist_thresh

    # Disable Core control on silver
    echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable

    # Setting b.L scheduler parameters
    echo 95 95 > /proc/sys/kernel/sched_upmigrate
    echo 85 85 > /proc/sys/kernel/sched_downmigrate
    echo 100 > /proc/sys/kernel/sched_group_upmigrate
    echo 10 > /proc/sys/kernel/sched_group_downmigrate
    echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

    # Turn off scheduler boost at the end
    echo 0 > /proc/sys/kernel/sched_boost

    # configure governor settings for silver cluster
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo 1209600 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
    echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo 1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl

    # configure governor settings for gold cluster
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
    echo 1612800 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq
    echo 1 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/pl

    # configure governor settings for gold+ cluster
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
    echo 1612800 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq
    echo 1 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl

    # configure input boost settings
    echo "0:1324800" > /sys/module/cpu_boost/parameters/input_boost_freq
    echo 120 > /sys/module/cpu_boost/parameters/input_boost_ms
    echo "0:0 1:0 2:0 3:0 4:2323200 5:0 6:0 7:2323200" > /sys/module/cpu_boost/parameters/powerkey_input_boost_freq
    echo 400 > /sys/module/cpu_boost/parameters/powerkey_input_boost_ms

    # Disable wsf, beacause we are using efk.
    # wsf Range : 1..1000 So set to bare minimum value 1.
    echo 1 > /proc/sys/vm/watermark_scale_factor


    # Enable bus-dcvs
    for device in /sys/devices/platform/soc
    do
        for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
        do
        echo "bw_hwmon" > $cpubw/governor
        echo "2288 4577 7110 9155 12298 14236 15258" > $cpubw/bw_hwmon/mbps_zones
        echo 4 > $cpubw/bw_hwmon/sample_ms
        echo 50 > $cpubw/bw_hwmon/io_percent
        echo 20 > $cpubw/bw_hwmon/hist_memory
        echo 10 > $cpubw/bw_hwmon/hyst_length
        echo 30 > $cpubw/bw_hwmon/down_thres
        echo 0 > $cpubw/bw_hwmon/guard_band_mbps
        echo 250 > $cpubw/bw_hwmon/up_scale
        echo 1600 > $cpubw/bw_hwmon/idle_mbps
        echo 14236 > $cpubw/max_freq
                echo 40 > $cpubw/polling_interval
        done

        for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
        do
        echo "bw_hwmon" > $llccbw/governor
        echo "1720 2929 3879 5931 6881 7980" > $llccbw/bw_hwmon/mbps_zones
        echo 4 > $llccbw/bw_hwmon/sample_ms
        echo 80 > $llccbw/bw_hwmon/io_percent
        echo 20 > $llccbw/bw_hwmon/hist_memory
        echo 10 > $llccbw/bw_hwmon/hyst_length
        echo 30 > $llccbw/bw_hwmon/down_thres
        echo 0 > $llccbw/bw_hwmon/guard_band_mbps
        echo 250 > $llccbw/bw_hwmon/up_scale
        echo 1600 > $llccbw/bw_hwmon/idle_mbps
        echo 6881 > $llccbw/max_freq
                echo 40 > $llccbw/polling_interval
        done

        for npubw in $device/*npu-npu-ddr-bw/devfreq/*npu-npu-ddr-bw
        do
        echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
        echo "bw_hwmon" > $npubw/governor
        echo "1720 2929 3879 5931 6881 7980" > $npubw/bw_hwmon/mbps_zones
        echo 4 > $npubw/bw_hwmon/sample_ms
        echo 80 > $npubw/bw_hwmon/io_percent
        echo 20 > $npubw/bw_hwmon/hist_memory
        echo 6  > $npubw/bw_hwmon/hyst_length
        echo 30 > $npubw/bw_hwmon/down_thres
        echo 0 > $npubw/bw_hwmon/guard_band_mbps
        echo 250 > $npubw/bw_hwmon/up_scale
        echo 0 > $npubw/bw_hwmon/idle_mbps
                echo 40 > $npubw/polling_interval
        echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
        done
    done

    # memlat specific settings are moved to seperate file under
    # device/target specific folder
    setprop vendor.dcvs.prop 1

    echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
    configure_memory_parameters

    ;;
esac

# Post-setup services
case "$target" in
    "msm8909" | "msm8916" | "msm8937" | "msm8952" | "msm8953" | "msm8994" | "msm8992" | "msm8996" | "msm8998" | "sdm660" | "apq8098_latv" | "sdm845" | "sdm710" | "msmnile" | "msmsteppe" | "sm6150" | "kona" | "lito" | "trinket" | "atoll" | "bengal" | "sdmshrike")
        setprop vendor.post_boot.parsed 1
    ;;
esac

# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
    image_version="10:"
    image_version+=`getprop ro.build.id`
    image_version+=":"
    image_version+=`getprop ro.build.version.incremental`
    image_variant=`getprop ro.product.name`
    image_variant+="-"
    image_variant+=`getprop ro.build.type`
    oem_version=`getprop ro.build.version.codename`
    echo 10 > /sys/devices/soc0/select_image
    echo $image_version > /sys/devices/soc0/image_version
    echo $image_variant > /sys/devices/soc0/image_variant
    echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# Parse misc partition path and set property
misc_link=$(ls -l /dev/block/bootdevice/by-name/misc)
real_path=${misc_link##*>}
setprop persist.vendor.mmi.misc_dev_path $real_path
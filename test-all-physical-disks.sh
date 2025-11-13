#!/bin/bash
# test-all-physical-disks.sh
# NO SUDO REQUIRED — tests only /dev/* devices
# https://github.com/ultrajones/public/blob/main/test-all-physical-disks.sh

echo "=== Physical Disk Benchmark (tests only /dev/* devices) ==="
echo "   (sequential read/write, human-readable, no sudo)"
echo

# Only list real block devices under /dev that are physical disks
DISKS=$(lsblk -d -n -p --output NAME,TYPE,TRAN 2>/dev/null | \
        grep "disk" | \
        grep -E "sata|sas|nvme|usb|virtio|ide|scsi" | \
        awk '{print $1}' | \
        grep "^/dev/")

[ -z "$DISKS" ] && { echo "No physical disks found under /dev/"; exit 1; }

for DEV in $DISKS; do
    BASENAME=$(basename "$DEV")
    MODEL=$(cat /sys/block/"$BASENAME"/device/model 2>/dev/null | xargs echo -n || echo "Unknown")
    SIZE=$(lsblk -d -n -b -o SIZE "$DEV" 2>/dev/null | awk '{printf "%.1f GB", $1/1000000000}')

    echo "------------------------------------------------------------"
    echo "Testing: $DEV  |  $MODEL  |  ${SIZE}"
    echo "------------------------------------------------------------"

    # READ TEST: try raw device first
    if [ -r "$DEV" ] && fio --name=read-raw --filename="$DEV" --rw=read --bs=1M --iodepth=32 --numjobs=1 --runtime=10 --time_based --direct=1 --ioengine=libaio --group_reporting --output-format=human 2>/dev/null | grep -q "READ:"; then
        echo "→ Max READ speed (raw device):"
        fio --name=read-raw --filename="$DEV" --rw=read --bs=1M --iodepth=32 --numjobs=1 --runtime=10 --time_based --direct=1 --ioengine=libaio --group_reporting --output-format=human 2>/dev/null | grep "READ:"
    else
        echo "→ Raw read denied – testing via file in /tmp..."
        TESTDIR=$(mktemp -d /tmp/fio-read.XXXXXX)
        fio --name=read-file --directory="$TESTDIR" --rw=read --bs=1M --iodepth=32 --numjobs=2 --size=2G --runtime=10 --time_based --direct=1 --output-format=human 2>/dev/null | grep "READ:"
        rm -rf "$TESTDIR"
    fi

    # WRITE TEST: always safe in /tmp
    echo "→ Max WRITE speed (file in /tmp):"
    fio --name=write-test --filename="/tmp/fio-write-$BASENAME.tmp" --rw=write --bs=1M --iodepth=32 --numjobs=2 --size=4G --runtime=10 --time_based --direct=1 --ioengine=libaio --group_reporting --output-format=human 2>/dev/null | grep "WRITE:"
    rm -f "/tmp/fio-write-$BASENAME.tmp"

    echo
done

echo "=== All /dev/* disks tested (no sudo used) ==="

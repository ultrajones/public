#!/bin/bash
# test-all-physical-disks.sh
# NO SUDO REQUIRED — works for normal users
# https://github.com/ultrajones/public/blob/main/test-all-physical-disks.sh

echo "=== Physical disk max-performance benchmark (no sudo) ==="
echo "   (sequential read/write, human-readable output)"
echo

# Find physical disks
DISKS=$(lsblk -d -n -p --output NAME,TRAN,TYPE 2>/dev/null | grep -E 'sata|sas|nvme|usb|virtio|ide' | grep disk | awk '{print $1}')

[ -z "$DISKS" ] && { echo "No physical disks found!"; exit 1; }

for DEV in $DISKS; do
    MODEL=$(cat /sys/block/$(basename $DEV)/device/model 2>/dev/null | xargs || echo "Unknown")
    SIZE=$(lsblk -d -n -b -o SIZE "$DEV" 2>/dev/null | awk '{printf "%.1f GB", $1/1000000000}')
    
    echo "------------------------------------------------------------"
    echo "Testing: $DEV  |  $MODEL  |  ${SIZE}"
    echo "------------------------------------------------------------"

    # READ test — try raw device first, fall back to mounted filesystem if no access
    if [ -r "$DEV" ] && fio --name=read-test --filename="$DEV" --rw=read --bs=1M --iodepth=32 --numjobs=1 --runtime=10 --time_based --direct=1 --ioengine=libaio --group_reporting --output-format=human 2>/dev/null | grep -q "READ:.*BW="; then
        fio --name=read-test --filename="$DEV" --rw=read --bs=1M --iodepth=32 --numjobs=1 --runtime=10 --time_based --direct=1 --ioengine=libaio --group_reporting --output-format=human 2>/dev/null | grep "READ:.*BW="
    else
        echo "→ No raw read access to $DEV, testing via /mnt or /tmp instead..."
        TESTDIR=$(mktemp -d /tmp/fio-test.XXXXXX)
        fio --name=read-test --directory="$TESTDIR" --rw=read --bs=1M --iodepth=32 --numjobs=2 --size=2G --runtime=10 --time_based --direct=1 --ioengine=libaio --group_reporting --output-format=human 2>/dev/null | grep "READ:.*BW="
        rm -rf "$TESTDIR"
    fi

    # WRITE test — always to /tmp (safe and never needs root)
    echo "→ Max WRITE speed (file in /tmp)..."
    fio --name=write-test \
      --filename=/tmp/fio-test-$(basename $DEV).tmp \
      --rw=write \
      --bs=1M \
      --iodepth=32 \
      --numjobs=2 \
      --size=4G \
      --runtime=10 \
      --time_based \
      --direct=1 \
      --ioengine=libaio \
      --group_reporting \
      --output-format=human 2>/dev/null | grep "WRITE:.*BW="

    rm -f /tmp/fio-test-$(basename $DEV).tmp
    echo
done

echo "=== All disks tested (no sudo used anywhere) ==="

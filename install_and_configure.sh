#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
	echo "Please run as root or with sudo privileges."
	exit 1
fi

# Update package list and install required packages
apt-get update && apt-get install -y procps imagemagick && rm -rf /var/lib/apt/lists/*

# Download the Brother drivers
mkdir -p /tmp/brother
cd /tmp/brother
wget https://download.brother.com/welcome/dlf105200/brscan4-0.4.11-1.amd64.deb
wget https://download.brother.com/welcome/dlf006652/brscan-skey-0.3.2-0.amd64.deb

# Install the Brother drivers
dpkg -i --force-all brscan4-0.4.11-1.amd64.deb
dpkg -i --force-all brscan-skey-0.3.2-0.amd64.deb

# Verify the installation
dpkg -l | grep 'Brother Scanner Driver'
dpkg -l | grep 'Brother Linux scanner S-KEY tool'

# Configure ImageMagick policy
sed -i '/pattern="PDF"/s/rights="none"/rights="read|write"/' /etc/ImageMagick-6/policy.xml

# Save the scanning script to /usr/local/sbin/brscans.sh
cat <<'EOF' >/usr/local/sbin/brscans.sh
#!/bin/bash
# Needs: apt-get install imagemagick

# Indicate destinations where to save copy of pdf and save logs
PDF_DEST1="/scans"
PDF_DEST2="/var/brscans"
LOG_FILE=/var/log/$(basename "$0" .sh).log

# Create save locations if they do not exist
mkdir -p $PDF_DEST1
mkdir -p $PDF_DEST2

# Stop hanged brscan-skey-exe processes
pkill -9 brscan-skey-exe

function logger() {
	currTime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	echo "$currTime|$1|$2"
	echo "$currTime|$1|$2" >>$LOG_FILE
}
logger INFO "SCRIPT STARTED!"

# Check for mandatory environment variables
if [[ -z "$NAME" || -z "$MODEL" || -z "$IPADDRESS" ]]; then
    echo "Environment variables NAME, MODEL, and IPADDRESS must be set."
    exit 1
fi

# Configure the printer
brsaneconfig4 -a name="$NAME" model="$MODEL" ip="$IPADDRESS"

# Verify the printer configuration
brsaneconfig4 -q

brscan-skey | while read -r msg; do

	F="$(sed -e 's/^\(.*\) is created\..*$/\1/' <<<$msg)"
	FB="${F%%.tif}"
	B=$(basename "$F")
	BB=$(basename "$FB")
	D=$(dirname "$F")

	logger DEBUG "F=$F"
	logger DEBUG "FB=$FB"
	logger DEBUG "B=$B"
	logger DEBUG "BB=$BB"
	logger DEBUG "D=$D"

	logger INFO "Received: brscan/$B"
	logger DEBUG "Saved raw copy of: brscan/$B to '$PDF_DEST1/$B'"

	Y="Failed: MISSING INPUT FILE"
	test -f "$F" && Y=$(convert -page A4 -density 100 "$F" "$PDF_DEST1/$BB.pdf" 2>&1)
	# test -f "$F" && Y=`convert -page A4 -density 100 "$F" "$PDF_DEST2/$BB.pdf" 2>&1`
	logger INFO "Conversion to $BB.pdf Y:${Y:-OK}"
	logger INFO "$PDF_DEST1/$BB.pdf Y:${Y:-OK}"
	# logger INFO "$PDF_DEST2/$BB.pdf Y:${Y:-OK}"
done

logger ERROR "brscan-skey died for some reason…"
EOF

chmod +x /usr/local/sbin/brscans.sh

# Clean up temporary directory
rm -rf /tmp/brother

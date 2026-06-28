#!/bin/bash -l

# Set directories
export parentDirectory=$1
export TMPDIR=${parentDirectory}

# Ensure parentDirectory exists
if [ -z "$parentDirectory" ]; then
        echo "The directory $parentDirectory doesn't exist, exiting" >&2
        exit 1
fi

# List all tar files in the zip (tar.gz files are not included)
tarList=($(find $parentDirectory -type f -iname "*.tar"))

# Ensure parentDirectory contains tar files
if [ ${#tarList[@]} -eq 0 ]; then
        echo "The directory $parentDirectory doesn't contain tar files, exiting" >&2
        exit 1
fi

tempDir=$(mktemp -d)
shaFile=$parentDirectory/sha256sum.lst
rm -f $shaFile

# Go through all the tar files and list the sha of all internal files
for tar in $(echo ${tarList[@]} | xargs -n1 | sort -u); do
        tar -xf $tar -C $tempDir
        trimmedTar=$(echo $tar | sed -r "s@${parentDirectory}@@")
        #find $tempDir -type f -exec sha256sum {} \; | while read shaLine; do
        find $tempDir -type f | sort | while read shaLine; do
	        shaCalc=$(sha256sum $shaLine)
                sha=$(echo $shaCalc | awk '{print $1}')
                file=$(echo $shaCalc | awk '{print $2}' | sed -r "s@${tempDir}@@")
                echo "$trimmedTar $file $sha" >> $shaFile
        done
        rm -rf $tempDir/*
done

rm -rf $tempDir
echo "Sha file: $shaFile"

# Verify all hash results appear only once per blob
cat $shaFile | grep -vi 'publish\|release-signatures' | while read LINE
do
	export SHA256=$(echo ${LINE} | awk '{print $NF}')
	if [ $(echo ${LINE} | grep -o ${SHA256} | wc -l) -ne "2" ]
	then
		echo "blob line with non-matching hash value:"
		echo ${LINE}
	fi
done


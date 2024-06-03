#!/bin/bash

source ~/src/bin/savv-shared-functions.sh

current_env=$(get_active_environment)

active_project=$(get_active_project)

is_frontend_project=$(is_frontend_project)

function incrementVersionNumbers() {
	# Path to the build.gradle file
	gradle_path="./android/app/build.gradle"
	package_json_path="./package.json"

	# Extract current versionCode and versionName
	current_version_code=$(awk '/versionCode/ {print $2}' $gradle_path)
	current_version_name=$(awk '/versionName/ {gsub(/"/, "", $2); print $2}' $gradle_path)

	# Calculate new versionCode and versionName
	new_version_code=$((current_version_code + 1))
	version_name_prefix=$(echo $current_version_name | awk -F'.' '{print $1 "." $2}')
	version_name_suffix=$(echo $current_version_name | awk -F'.' '{print $3}')
	new_version_name_suffix=$((version_name_suffix + 1))
	new_version_name="$version_name_prefix.$new_version_name_suffix"

	# Update build.gradle with new versionCode and versionName
	sed -i "s/versionCode $current_version_code/versionCode $new_version_code/" $gradle_path
	sed -i "s/versionName \"$current_version_name\"/versionName \"$new_version_name\"/" $gradle_path

	# Extract and increment version in package.json
	current_package_version=$(jq -r '.version' $package_json_path)
	version_parts=(${current_package_version//./ })
	major_version=${version_parts[0]}
	minor_version=${version_parts[1]}
	patch_version=$((version_parts[2] + 1))
	new_package_version="${major_version}.${minor_version}.${patch_version}"
	jq ".version = \"$new_package_version\"" $package_json_path > temp.json && mv temp.json $package_json_path
}

if [ "$current_env" != "prod" ]; then
	echo "This script is meant to run in a prod environment. It creates a prod build."
	exit 1
fi

if [ "$is_frontend_project" != "true" ]; then
	echo "The current project must be a frontend project."
	exit 1
fi


path=$($HOME/src/bin/commandline/fe.sh)
cd "$path" || return
echo "--------------------"
rm android/app/build www -rf
cp ./src/app/_environments/environment.prod.ts ./src/app/_environments/environment.ts
echo "Incrementing version numbers"
incrementVersionNumbers
npm run build:prod
echo "--------------------"
npx cap sync android
echo "--------------------"
cordova-res
echo "--------------------"
python3 updatescript.py
echo "--------------------"
cd android/
 ./gradlew bundleRelease
echo "--------------------"
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore ~/src/my-release-key.keystore `find . -name app-release.aab`  my_alias

exit 0

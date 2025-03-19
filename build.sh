#!/bin/bash

source .env

echo $DOCKERHUB_USERNAME

DockerfileName="$DOCKERFILENAME"

if [[ -f $DockerfileName ]]
then
    echo "Dockerfile exists already"
    echo "FROM nginx:alpine" > $DockerfileName
else 
    ## file does not exist, create it
    echo "File does not exist..."
    echo "Creating it ..."
    sleep 3
    touch $DockerfileName
    echo "$DockerfileName file created ..."
    
    echo "FROM nginx:alpine" >> $DockerfileName    
fi

echo "COPY . /usr/share/nginx/html" >> $DockerfileName
echo "WORKDIR /usr/share/nginx/html" >> $DockerfileName

sudo docker build -t $APP_NAME:$BUILD_VERSION .

## Push to Docker Hub
DOCKERHUB_REPO="$DOCKERHUB_USERNAME/$APP_NAME"
sudo docker tag $APP_NAME:$BUILD_VERSION $DOCKERHUB_REPO:$BUILD_VERSION
echo "Pushing image to Docker Hub..."
echo "$DOCKERHUB_PASSWORD" | sudo docker login -u "$DOCKERHUB_USERNAME" --password-stdin
sudo docker push $DOCKERHUB_REPO:$BUILD_VERSION

## Run Docker Scout Analysis
echo "Running Docker Scout Analysis..."
sudo docker scout quickview $DOCKERHUB_REPO:$BUILD_VERSION

## Remove previously running Docker container
echo "Stopping any previously running container ... Please wait..."
sleep 2
sudo docker stop $APP_NAME 

echo "Running basic cleanups ..."
sleep 2
sudo docker rm $APP_NAME

echo "Running your container ... ---------------------------"
sudo docker run -d -p $APP_PORT:80 --name $APP_NAME $APP_NAME:$BUILD_VERSION 

echo "Application deployed successfully!"

## Push updates to GitHub
echo "Pushing updates to GitHub..."
git add .
git commit -m "Automated update: $(10)"
git push origin master

echo "GitHub updates pushed successfully!"

## Setup CRON Job to run build.sh every 10 minutes
CRON_JOB="*/10 * * * * /bin/bash $ . $0 >> /var/log/build_script.log 2>&1"

# Check if the CRON job already exists
crontab -l | grep -qF "$CRON_JOB"

if [[ $? -ne 0 ]]; then
    echo "Setting up CRON job to run this script every 10 minutes..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "CRON job added successfully!"
else
    echo "CRON job already exists. No changes made."
fi

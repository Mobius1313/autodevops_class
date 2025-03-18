#!/bin/bash

source .env

echo "DockerHub Username: $DOCKERHUB_USERNAME"

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

## Build Docker image
sudo docker build -t $APP_NAME:$BUILD_VERSION .

## Push the image to Docker Hub
echo "Pushing the image to Docker Hub..."
sudo docker tag $APP_NAME:$BUILD_VERSION $DOCKERHUB_USERNAME/$APP_NAME:$BUILD_VERSION
sudo docker push $DOCKERHUB_USERNAME/$APP_NAME:$BUILD_VERSION

## Remove previously running Docker container
echo "Stopping any previously running container ... Please wait..."
sleep 2
sudo docker stop $APP_NAME 

echo "Running basic cleanups ..."
sleep 2
sudo docker rm $APP_NAME

## Run the container
echo "Running your container ... ---------------------------"
sudo docker run -d -p $APP_PORT:80 --name $APP_NAME $DOCKERHUB_USERNAME/$APP_NAME:$BUILD_VERSION 

echo "Application deployed successfully!"

## Push the image to Docker Hub
echo "Tagging and pushing image to Docker Hub..."
sudo docker tag $APP_NAME:$BUILD_VERSION $DOCKERHUB_USERNAME/$APP_NAME:$BUILD_VERSION
sudo docker login -u "$DOCKERHUB_USERNAME" -p "$DOCKERHUB_PASSWORD"
sudo docker push $DOCKERHUB_USERNAME/$APP_NAME:$BUILD_VERSION

## Analyze the image using Docker Scout
echo "Analyzing the image with Docker Scout..."
docker scout quickview $DOCKERHUB_USERNAME/$APP_NAME:$BUILD_VERSION

## Setup cron job to run this script every 10 minutes
echo "Configuring cron job..."
CRON_JOB="*/10 * * * * $(whoami) /bin/bash $(pwd)/build.sh >> $(pwd)/cron.log 2>&1"

# Check if cron job already exists
(crontab -l 2>/dev/null | grep -v -F "$CRON_JOB"; echo "$CRON_JOB") | crontab -

echo "Cron job configured successfully!"

## Auto-push updates to GitHub every 10 minutes
echo "Pushing updates to GitHub..."
git add .
git commit -m "Automated commit: $(now)"
git push origin main

echo "GitHub updates pushed successfully!"

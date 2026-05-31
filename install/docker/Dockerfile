FROM eclipse-temurin:8-jre
WORKDIR /server
COPY . .
ENV EULA=false
ENV JVM_OPTS="-Xms4G -Xmx8G -XX:+UseG1GC"
EXPOSE 25565
VOLUME ["/server/world", "/server/backups"]
ENTRYPOINT sh -c 'echo "eula=$EULA" > eula.txt && java $JVM_OPTS -jar forge-1.7.10-10.13.4.1614-1.7.10-universal.jar nogui'

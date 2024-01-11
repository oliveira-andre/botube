# Botube

### Configure project

- install [youtube-dl](https://github.com/yt-dlp/yt-dlp/wiki/Installation)

- install [ngrok](https://ngrok.com/)

- create a bot on telegram take the token and paste on .env file (follow the .env.example)

- run ngrok listening on port 9292
```
ngrok http 9292
```

- take the https link and paste on .env file (follow the .env.example)

- install dependencies
```
bundle install
```

- run the project
```
APP_ENV=development bundle exec rackup config.ru -o 0.0.0.0
```

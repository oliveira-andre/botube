# Sinatra Telegram Bot Template

### Configure project

- put your environment variables on `config/docker.env`

- build the image and install dependencies with
```
docker-compose build
```

or

```
bundle install
```

### Running the project

```
docker-compose up --build
```

or

```
APP_ENV=development bundle exec rackup config.ru -o 0.0.0.0
```

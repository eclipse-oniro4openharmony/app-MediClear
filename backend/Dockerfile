FROM node:20-bookworm-slim

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY src ./src

ENV NODE_ENV=production
ENV PORT=8080
ENV MONGO_URL=mongodb://mongo:27017
ENV MONGO_DB_NAME=mediclear

EXPOSE 8080

CMD ["npm", "start"]

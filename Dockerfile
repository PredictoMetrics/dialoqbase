FROM node:20 as server

WORKDIR /app

RUN apt-get update && apt-get -y install g++ make python3
# RUN npm install -g node-gyp

COPY ./server/ .

RUN yarn config set registry https://registry.npmjs.org/
RUN yarn config set network-timeout 1200000
RUN yarn install

RUN yarn build

FROM node:20 as build
WORKDIR /app

RUN apt-get update
RUN npm --no-update-notifier --no-fund --global install pnpm

COPY . .
RUN npm install -g node-gyp
RUN pnpm install

RUN pnpm build

FROM node:20
WORKDIR /app

RUN yarn config set registry https://registry.npmjs.org/
RUN yarn config set network-timeout 1200000

RUN apt-get update && apt-get -y install --no-install-recommends ca-certificates git git-lfs openssh-client curl jq cmake sqlite3 openssl psmisc python3
RUN apt-get -y install g++ make
RUN apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/
RUN apt-get install -y redis
RUN npm --no-update-notifier --no-fund --global install pnpm
# Copy API
COPY --from=server /app/dist/ .
COPY --from=server /app/prisma/ ./prisma
COPY --from=server /app/package.json .
# Copy UI
COPY --from=build /app/app/ui/dist/ ./public
# Copy widgets 
COPY --from=build /app/app/widget/dist/assets/ ./public/assets
COPY --from=build /app/app/widget/dist/index.html ./public/bot.html
# Copy script
COPY --from=build /app/app/script/dist/chat.min.js ./public/chat.min.js

RUN yarn install --production

ENV NODE_ENV=production

EXPOSE 3000

CMD ["yarn", "start"]

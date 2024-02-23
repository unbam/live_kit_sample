import * as admin from "firebase-admin";
import * as functionsV2 from "firebase-functions/v2";
import { AccessToken } from "livekit-server-sdk";

admin.initializeApp();

export const createToken = functionsV2.https.onRequest(
  { region: "asia-northeast1" },
  (request, response) => {
    console.log("createToken called");
    if (!request.query.userId || !request.query.roomId) {
      response.status(400).send("parameter required.");
      return;
    }
    const userId = request.query.userId as string;
    const roomId = request.query.roomId as string;
    const at = new AccessToken(
      process.env.LIVEKIT_API_KEY,
      process.env.LIVEKIT_API_SECRET,
      {
        identity: userId,
      }
    );
    at.addGrant({ roomJoin: true, room: roomId });
    const token = at.toJwt();
    console.log(
      `createToken: userId: ${userId}, roomId: ${roomId} token: ${token}`
    );

    response.send(token);
  }
);

export const sendMessage = functionsV2.https.onRequest(
  { region: "asia-northeast1" },
  async (request, response) => {
    console.log("sendMessage called");
    if (
      !request.query.callId ||
      !request.query.callerUserId ||
      !request.query.isCall ||
      !request.query.toIOS
    ) {
      response.status(400).send("parameter required.");
      return;
    }
    const callId = request.query.callId as string;
    const callerUserId = request.query.callerUserId as string;
    const isCall = (request.query.isCall as string) == "1" ? true : false;
    const toIOS = (request.query.toIOS as string) == "1" ? true : false;
    const token = toIOS ? (process.env.TOKEN_IOS as string) : (process.env.TOKEN_ANDROID as string);
    const callerUserName = callerUserId == "1" ? "ABC Inc." : "XYZ Inc.";
    const callerIconUrl =
      "https://img.icons8.com/ios-filled/50/user-male-circle.png";

    const promises: Promise<void>[] = [];
    promises.push(
      fcm(token, isCall, callId, callerUserId, callerUserName, callerIconUrl)
    );

    await Promise.all(promises);
    response.send("success");
  }
);

export const fcm = async (
  token: string,
  isCall: boolean,
  callId: string,
  callerUserId: string,
  callerUserName: string,
  callerIconUrl: string
): Promise<void> => {
  if (isCall) {
    const message: admin.messaging.Message = {
      data: {
        type: "call",
        callId: callId,
        callerUserId: callerUserId,
        callerUserName: callerUserName,
        callerIconUrl: callerIconUrl,
      },
      token: token,
    };
    // FCMを送信
    await admin
      .messaging()
      .send(message)
      .then(() => {
        console.log(`fcm: type:call token ${token}`);
      })
      .catch((error) => {
        console.error(
          `fcm type:call token: ${token} errorCode: ${error.code} message: ${error}`
        );
      });
  } else {
    const tokenMessage: admin.messaging.TokenMessage = {
      notification: {
        title: "title",
        body: "body",
      },
      android: {
        notification: {
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
          },
        },
      },
      data: {
        type: "message",
        title: "titleFromData",
        body: "bodyFromData",
      },
      token: token,
    };

    await admin
      .messaging()
      .send(tokenMessage)
      .then(() => {
        console.log(`fcm: type:message token ${token}`);
      })
      .catch((error) => {
        console.error(
          `fcm type:message token: ${token} errorCode: ${error.code} message: ${error}`
        );
      });
  }
};

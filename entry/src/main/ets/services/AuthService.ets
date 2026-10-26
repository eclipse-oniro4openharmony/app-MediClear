import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import http from '@ohos.net.http';
import {
  buildAuthForgotPasswordUrl,
  buildAuthLoginUrl,
  buildAuthLogoutUrl,
  buildAuthRefreshUrl,
  buildAuthRegisterUrl,
  buildAuthResetPasswordUrl,
  buildAuthVerifyEmailUrl
} from './BackendConfig';

const AUTH_PREFERENCES_NAME = 'mediclear_auth_session';
const ACCESS_TOKEN_KEY = 'access_token';
const REFRESH_TOKEN_KEY = 'refresh_token';
const ACCESS_TOKEN_EXPIRY_KEY = 'access_token_expiry';
const USER_ID_KEY = 'user_id';
const USER_EMAIL_KEY = 'user_email';

export class AuthUser {
  id: string = '';
  email: string = '';

  constructor(id: string = '', email: string = '') {
    this.id = id;
    this.email = email;
  }
}

class AuthSessionResponse {
  accessToken: string = '';
  refreshToken: string = '';
  accessTokenExpiresIn: number = 0;
  user: AuthUser = new AuthUser();
}

class AuthErrorResponse {
  error: string = '';
  message: string = '';
}

class AuthCredentialsRequest {
  email: string = '';
  password: string = '';

  constructor(email: string, password: string) {
    this.email = email;
    this.password = password;
  }
}

class AuthEmailRequest {
  email: string = '';

  constructor(email: string) {
    this.email = email;
  }
}

class AuthEmailCodeRequest {
  email: string = '';
  code: string = '';

  constructor(email: string, code: string) {
    this.email = email;
    this.code = code;
  }
}

class AuthRefreshRequest {
  refreshToken: string = '';

  constructor(refreshToken: string) {
    this.refreshToken = refreshToken;
  }
}

class AuthPasswordResetRequest {
  email: string = '';
  code: string = '';
  password: string = '';

  constructor(email: string, code: string, password: string) {
    this.email = email;
    this.code = code;
    this.password = password;
  }
}

export class AuthService {
  private static accessTokenValue: string = '';
  private static refreshTokenValue: string = '';
  private static accessTokenExpiry: number = 0;
  private static currentUserId: string = '';
  private static currentUserEmail: string = '';

  static async restoreSession(context: common.Context): Promise<AuthUser | null> {
    const store = await preferences.getPreferences(context, AUTH_PREFERENCES_NAME);
    AuthService.accessTokenValue = (await store.get(ACCESS_TOKEN_KEY, '')).toString();
    AuthService.refreshTokenValue = (await store.get(REFRESH_TOKEN_KEY, '')).toString();
    AuthService.accessTokenExpiry = Number((await store.get(ACCESS_TOKEN_EXPIRY_KEY, 0)).toString());
    AuthService.currentUserId = (await store.get(USER_ID_KEY, '')).toString();
    AuthService.currentUserEmail = (await store.get(USER_EMAIL_KEY, '')).toString();

    if (AuthService.accessTokenValue.length > 0 && AuthService.accessTokenExpiry > Date.now() + 60000 &&
      AuthService.currentUserId.length > 0) {
      return new AuthUser(AuthService.currentUserId, AuthService.currentUserEmail);
    }
    if (AuthService.refreshTokenValue.length === 0) {
      return null;
    }

    try {
      return await AuthService.refreshSession(context);
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('401:')) {
        await AuthService.clearSession(context);
        return null;
      }
      throw error instanceof Error ? error : new Error(JSON.stringify(error));
    }
  }

  static async register(email: string, password: string): Promise<void> {
    await AuthService.postJson(buildAuthRegisterUrl(), new AuthCredentialsRequest(email, password));
  }

  static async verifyEmail(email: string, code: string): Promise<void> {
    await AuthService.postJson(buildAuthVerifyEmailUrl(), new AuthEmailCodeRequest(email, code));
  }

  static async login(context: common.Context, email: string, password: string): Promise<AuthUser> {
    const response = await AuthService.postJson(buildAuthLoginUrl(), new AuthCredentialsRequest(email, password));
    const session = JSON.parse(response) as AuthSessionResponse;
    await AuthService.applySession(context, session);
    return new AuthUser(session.user.id, session.user.email);
  }

  static async refreshSession(context: common.Context): Promise<AuthUser> {
    if (AuthService.refreshTokenValue.length === 0) {
      throw new Error('Your session has expired. Please log in again.');
    }
    const response = await AuthService.postJson(buildAuthRefreshUrl(),
      new AuthRefreshRequest(AuthService.refreshTokenValue));
    const session = JSON.parse(response) as AuthSessionResponse;
    await AuthService.applySession(context, session);
    return new AuthUser(session.user.id, session.user.email);
  }

  static async getValidAccessToken(context: common.Context): Promise<string> {
    if (AuthService.accessTokenValue.length > 0 && AuthService.accessTokenExpiry > Date.now() + 60000) {
      return AuthService.accessTokenValue;
    }
    await AuthService.refreshSession(context);
    return AuthService.accessTokenValue;
  }

  static async logout(context: common.Context): Promise<void> {
    const refreshToken = AuthService.refreshTokenValue;
    try {
      if (refreshToken.length > 0) {
        await AuthService.postJson(buildAuthLogoutUrl(), new AuthRefreshRequest(refreshToken));
      }
    } catch (error) {
      console.warn('[MediClearAuth] server logout failed: ' + JSON.stringify(error));
    } finally {
      await AuthService.clearSession(context);
    }
  }

  static async requestPasswordReset(email: string): Promise<void> {
    await AuthService.postJson(buildAuthForgotPasswordUrl(), new AuthEmailRequest(email));
  }

  static async resetPassword(email: string, code: string, password: string): Promise<void> {
    await AuthService.postJson(buildAuthResetPasswordUrl(), new AuthPasswordResetRequest(email, code, password));
  }

  private static async applySession(context: common.Context, session: AuthSessionResponse): Promise<void> {
    if (session.accessToken.length === 0 || session.refreshToken.length === 0 || session.user.id.length === 0) {
      throw new Error('The backend returned an invalid sign-in response');
    }
    AuthService.accessTokenValue = session.accessToken;
    AuthService.refreshTokenValue = session.refreshToken;
    AuthService.accessTokenExpiry = Date.now() + session.accessTokenExpiresIn * 1000;
    AuthService.currentUserId = session.user.id;
    AuthService.currentUserEmail = session.user.email;

    const store = await preferences.getPreferences(context, AUTH_PREFERENCES_NAME);
    await store.put(ACCESS_TOKEN_KEY, AuthService.accessTokenValue);
    await store.put(REFRESH_TOKEN_KEY, AuthService.refreshTokenValue);
    await store.put(ACCESS_TOKEN_EXPIRY_KEY, AuthService.accessTokenExpiry);
    await store.put(USER_ID_KEY, AuthService.currentUserId);
    await store.put(USER_EMAIL_KEY, AuthService.currentUserEmail);
    await store.flush();
  }

  private static async clearSession(context: common.Context): Promise<void> {
    AuthService.accessTokenValue = '';
    AuthService.refreshTokenValue = '';
    AuthService.accessTokenExpiry = 0;
    AuthService.currentUserId = '';
    AuthService.currentUserEmail = '';

    const store = await preferences.getPreferences(context, AUTH_PREFERENCES_NAME);
    await store.put(ACCESS_TOKEN_KEY, '');
    await store.put(REFRESH_TOKEN_KEY, '');
    await store.put(ACCESS_TOKEN_EXPIRY_KEY, 0);
    await store.put(USER_ID_KEY, '');
    await store.put(USER_EMAIL_KEY, '');
    await store.flush();
  }

  private static async postJson(url: string, body: Object): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 20000,
        connectTimeout: 10000
      });
      const result = response.result.toString();
      if (response.responseCode < 200 || response.responseCode >= 300) {
        let message = 'Authentication request failed: ' + response.responseCode.toString();
        try {
          const errorResult = JSON.parse(result) as AuthErrorResponse;
          if (typeof errorResult.error === 'string' && errorResult.error.length > 0) {
            message = response.responseCode.toString() + ': ' + errorResult.error;
          } else if (typeof errorResult.message === 'string' && errorResult.message.length > 0) {
            message = response.responseCode.toString() + ': ' + errorResult.message;
          }
        } catch (_error) {
        }
        throw new Error(message);
      }
      return result;
    } finally {
      request.destroy();
    }
  }
}

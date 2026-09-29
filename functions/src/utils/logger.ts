/**
 * Ludus Logging Utility
 *
 * Provides consistent, structured logging for all endpoints
 * Format: [LUDUS] [ENDPOINT] [LEVEL] [TIMESTAMP] MESSAGE
 * Example: [LUDUS] [API/getDialogueTree] [INFO] 2026-10-01T09:15:30.123Z Dialogue tree loaded
 *
 * Designed for debugging on VR devices (easy to grep logs)
 */

export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
}

export interface LogContext {
  endpoint?: string;
  playerId?: string;
  npcId?: string;
  duration?: number; // milliseconds
  errorCode?: number; // HTTP status
  userAgent?: string; // Device info
}

class Logger {
  private static readonly PREFIX = '[LUDUS]';

  /**
   * Format timestamp as ISO string with milliseconds
   */
  private static getTimestamp(): string {
    return new Date().toISOString();
  }

  /**
   * Format endpoint name for logs
   */
  private static formatEndpoint(endpoint?: string): string {
    return endpoint ? `[${endpoint}]` : '';
  }

  /**
   * Main logging method
   */
  private static log(
    level: LogLevel,
    message: string,
    context?: LogContext,
    extra?: unknown
  ): void {
    const timestamp = this.getTimestamp();
    const endpoint = this.formatEndpoint(context?.endpoint);
    const parts = [this.PREFIX, endpoint, `[${level}]`, timestamp, message];
    const logMessage = parts.filter(p => p).join(' ');

    // Add context info if provided
    const contextStr = context
      ? ` | playerId=${context.playerId}, npcId=${context.npcId}, duration=${context.duration}ms`
      : '';

    const finalMessage = logMessage + contextStr;

    // Route to appropriate console method
    if (level === LogLevel.ERROR) {
      console.error(finalMessage, extra || '');
    } else if (level === LogLevel.WARN) {
      console.warn(finalMessage, extra || '');
    } else {
      console.log(finalMessage, extra || '');
    }
  }

  /**
   * Log info level (typical operation flow)
   */
  static info(message: string, context?: LogContext): void {
    this.log(LogLevel.INFO, message, context);
  }

  /**
   * Log debug level (detailed debugging info)
   */
  static debug(message: string, context?: LogContext, extra?: unknown): void {
    this.log(LogLevel.DEBUG, message, context, extra);
  }

  /**
   * Log warning level (something unexpected but recoverable)
   */
  static warn(message: string, context?: LogContext): void {
    this.log(LogLevel.WARN, message, context);
  }

  /**
   * Log error level (failure)
   */
  static error(message: string, error?: unknown, context?: LogContext): void {
    this.log(LogLevel.ERROR, message, context, error);
  }

  /**
   * Log endpoint success (for profiling)
   */
  static success(
    message: string,
    endpoint: string,
    duration: number,
    context?: Omit<LogContext, 'endpoint' | 'duration'>
  ): void {
    this.info(`✓ ${message} (${duration}ms)`, {
      ...context,
      endpoint,
      duration,
    });
  }

  /**
   * Log endpoint failure (for profiling & debugging)
   */
  static failure(
    message: string,
    endpoint: string,
    duration: number,
    errorCode: number,
    context?: Omit<LogContext, 'endpoint' | 'duration' | 'errorCode'>
  ): void {
    this.error(`✗ ${message} (${duration}ms, code ${errorCode})`, undefined, {
      ...context,
      endpoint,
      duration,
      errorCode,
    });
  }
}

export default Logger;

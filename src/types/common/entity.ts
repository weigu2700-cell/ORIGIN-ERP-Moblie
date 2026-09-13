/**
 * 后端所有 Long 均以 JSON 字符串返回，避免雪花 ID 超出 JavaScript 安全整数范围。
 */
export type EntityId = string;

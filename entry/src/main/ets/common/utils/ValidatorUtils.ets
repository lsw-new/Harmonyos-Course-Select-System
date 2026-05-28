// 表单字段校验工具

export interface ValidationResult {
  ok: boolean;
  message?: string;
}

export class ValidatorUtils {
  static required(value: string, label: string = '该项'): ValidationResult {
    if (!value || value.trim().length === 0) {
      return { ok: false, message: `${label}不能为空` };
    }
    return { ok: true };
  }

  static studentId(value: string): ValidationResult {
    const re = /^[A-Za-z0-9]{6,20}$/;
    if (!re.test(value)) {
      return { ok: false, message: '学号格式不正确' };
    }
    return { ok: true };
  }

  static phone(value: string): ValidationResult {
    const re = /^1[3-9]\d{9}$/;
    if (!re.test(value)) {
      return { ok: false, message: '手机号格式不正确' };
    }
    return { ok: true };
  }

  static email(value: string): ValidationResult {
    const re = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
    if (!re.test(value)) {
      return { ok: false, message: '邮箱格式不正确' };
    }
    return { ok: true };
  }

  static password(value: string): ValidationResult {
    if (value.length < 8 || value.length > 32) {
      return { ok: false, message: '密码长度需 8-32 位' };
    }
    let categories = 0;
    if (/[a-z]/.test(value)) categories++;
    if (/[A-Z]/.test(value)) categories++;
    if (/\d/.test(value)) categories++;
    if (/[^A-Za-z0-9]/.test(value)) categories++;
    if (categories < 2) {
      return { ok: false, message: '密码至少包含字母、数字、符号中的两种' };
    }
    return { ok: true };
  }

  static match(a: string, b: string, label: string = '两次输入'): ValidationResult {
    if (a !== b) {
      return { ok: false, message: `${label}不一致` };
    }
    return { ok: true };
  }

  static passwordStrength(value: string): 'weak' | 'medium' | 'strong' {
    let score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (/[A-Z]/.test(value)) score++;
    if (/[^A-Za-z0-9]/.test(value)) score++;
    if (score <= 1) return 'weak';
    if (score <= 3) return 'medium';
    return 'strong';
  }
}

"use client";

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import './login.css';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (username && password) {
      setLoading(true);
      setError(false);
      
      // Mock login delay matching the HTML prototype
      setTimeout(() => {
        setLoading(false);
        router.push('/'); // Redirect to dashboard
      }, 1500);
    } else {
      setError(true);
    }
  };

  return (
    <div className="login-page-wrapper">
      <div className="login-container">
        <div className="login-header">
          <h1>تسجيل الدخول</h1>
          <p>النظام الوطني للحالة المدنية</p>
          <div className="login-divider"></div>
        </div>
        
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label" htmlFor="username">اسم المستخدم</label>
            <input 
              className="form-input" 
              type="text" 
              id="username" 
              placeholder="أدخل اسم المستخدم" 
              required
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
          </div>
          
          <div className="form-group">
            <label className="form-label" htmlFor="password">كلمة المرور</label>
            <input 
              className="form-input" 
              type="password" 
              id="password" 
              placeholder="أدخل كلمة المرور" 
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            {error && <p className="error-msg visible">بيانات الدخول غير صحيحة</p>}
          </div>
          
          <button type="submit" className="btn-submit" disabled={loading}>
            {loading ? 'جاري التحقق...' : 'دخول'}
          </button>
        </form>
      </div>
    </div>
  );
}

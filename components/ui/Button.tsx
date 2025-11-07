
import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'icon';
  children: React.ReactNode;
}

export const Button: React.FC<ButtonProps> = ({ variant = 'primary', size = 'md', children, ...props }) => {
  const baseClasses = "font-semibold focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-ring-light dark:focus:ring-ring-dark focus:ring-offset-background-light dark:focus:ring-offset-background-dark transition-colors duration-200 flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed";
  
  const sizeClasses = {
      md: 'px-4 py-2 rounded-lg text-sm',
      sm: 'px-3 py-1.5 rounded-md text-xs',
      icon: 'h-10 w-10 rounded-lg'
  }

  const variantClasses = {
    primary: 'bg-primary-light text-white hover:bg-opacity-90 dark:bg-primary-dark dark:text-background-dark focus:ring-primary-light dark:focus:ring-primary-dark',
    secondary: 'bg-card-light dark:bg-card-dark border border-border-light dark:border-border-dark text-text-primary-light dark:text-text-primary-dark hover:bg-background-light dark:hover:bg-border-dark',
    ghost: 'bg-transparent text-text-secondary-light dark:text-text-secondary-dark hover:bg-gray-100 dark:hover:bg-border-dark'
  };

  return (
    <button className={`${baseClasses} ${sizeClasses[size]} ${variantClasses[variant]}`} {...props}>
      {children}
    </button>
  );
};
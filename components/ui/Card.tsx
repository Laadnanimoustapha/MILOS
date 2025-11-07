
import React from 'react';

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export const Card: React.FC<CardProps> = ({ children, className = '' }) => {
  return (
    <div className={`bg-card-light dark:bg-card-dark border border-border-light dark:border-border-dark rounded-lg shadow-sm p-4 sm:p-6 ${className}`}>
      {children}
    </div>
  );
};

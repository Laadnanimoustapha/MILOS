
import React from 'react';
import { KpiData } from '../../types';

interface KpiCardProps {
  data: KpiData;
}

const TrendIcon: React.FC<{ value: number }> = ({ value }) => {
  const isPositive = value >= 0;
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className={`w-4 h-4 mr-1 ${isPositive ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'}`}>
      {isPositive ? <path d="M12 5l0 14" /><path d="M18 S11l-6 -6" /><path d="M6 11l6 -6" /> : <path d="M12 5l0 14" /><path d="M18 13l-6 6" /><path d="M6 13l6 6" />}
    </svg>
  );
};

export const KpiCard: React.FC<KpiCardProps> = ({ data }) => {
  const formattedValue = new Intl.NumberFormat('en-US', {
    notation: 'compact',
    maximumFractionDigits: 2
  }).format(data.value);

  const isPositive = data.change >= 0;

  return (
    <div className="flex flex-col justify-center h-full">
      <p className="text-4xl sm:text-5xl font-bold text-text-primary-light dark:text-text-primary-dark tracking-tight">{formattedValue}</p>
      <div className="flex items-center mt-2 gap-2">
         <div className={`flex items-center px-2 py-0.5 rounded-full text-sm font-semibold ${isPositive ? 'bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-300' : 'bg-red-100 dark:bg-red-900/50 text-red-700 dark:text-red-300'}`}>
            <TrendIcon value={data.change} />
            <span>{data.change.toFixed(1)}%</span>
        </div>
        <span className="text-text-muted-light dark:text-text-muted-dark text-sm">vs last period</span>
      </div>
    </div>
  );
};
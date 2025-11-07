
import React from 'react';
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { TimeSeriesData, CategoricalData } from '../../types';

const COLORS = ['#818cf8', '#a78bfa', '#f472b6', '#fb923c', '#4ade80', '#38bdf8', '#fbbf24'];

const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="rounded-lg border border-border-dark bg-card-dark p-2 text-sm shadow-sm">
          <div className="grid grid-cols-2 gap-2">
            <div className="flex flex-col space-y-1">
              <span className="text-text-muted-dark">{label}</span>
              <span className="font-bold text-text-primary-dark">
                {new Intl.NumberFormat().format(payload[0].value)}
              </span>
            </div>
          </div>
        </div>
      );
    }
    return null;
};

export const LineChartComponent: React.FC<{ data: TimeSeriesData }> = ({ data }) => (
  <ResponsiveContainer width="100%" height="100%">
    <LineChart data={data} margin={{ top: 5, right: 10, left: -20, bottom: -10 }}>
      <CartesianGrid strokeDasharray="3 3" stroke="currentColor" opacity={0.1} />
      <XAxis dataKey="name" stroke="currentColor" fontSize={12} tickLine={false} axisLine={false} dy={10} />
      <YAxis stroke="currentColor" fontSize={12} tickLine={false} axisLine={false} dx={-5} tickFormatter={(value) => new Intl.NumberFormat('en-US', { notation: 'compact', compactDisplay: 'short' }).format(value as number)} />
      <Tooltip content={<CustomTooltip />} cursor={{ stroke: 'currentColor', strokeWidth: 1, strokeDasharray: '3 3' }}/>
      <Line type="monotone" dataKey="value" stroke="#818cf8" strokeWidth={2.5} dot={{ r: 0 }} activeDot={{ r: 6, fill: '#4f46e5', stroke: 'white', strokeWidth: 2 }} />
    </LineChart>
  </ResponsiveContainer>
);

export const BarChartComponent: React.FC<{ data: CategoricalData }> = ({ data }) => (
  <ResponsiveContainer width="100%" height="100%">
    <BarChart data={data} margin={{ top: 5, right: 10, left: -20, bottom: -10 }}>
       <CartesianGrid strokeDasharray="3 3" stroke="currentColor" opacity={0.1} />
      <XAxis dataKey="name" stroke="currentColor" fontSize={12} tickLine={false} axisLine={false} dy={10} />
      <YAxis stroke="currentColor" fontSize={12} tickLine={false} axisLine={false} dx={-5} tickFormatter={(value) => new Intl.NumberFormat('en-US', { notation: 'compact', compactDisplay: 'short' }).format(value as number)} />
      <Tooltip content={<CustomTooltip />} cursor={{fill: 'currentColor', opacity: 0.1}} />
      <Bar dataKey="value" fill="#818cf8" radius={[4, 4, 0, 0]} />
    </BarChart>
  </ResponsiveContainer>
);

export const PieChartComponent: React.FC<{ data: CategoricalData }> = ({ data }) => (
  <ResponsiveContainer width="100%" height="100%">
    <PieChart>
      <Tooltip content={<CustomTooltip />} />
      <Legend iconType="circle" verticalAlign="bottom" height={40} wrapperStyle={{fontSize: "12px", color: "currentColor"}}/>
      <Pie data={data} dataKey="value" nameKey="name" cx="50%" cy="45%" innerRadius={'55%'} outerRadius={'90%'} fill="#8884d8" paddingAngle={2}>
        {data.map((entry, index) => (
          <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} stroke={''} />
        ))}
      </Pie>
    </PieChart>
  </ResponsiveContainer>
);
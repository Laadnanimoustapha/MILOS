
export enum WidgetType {
  KPI = 'KPI',
  LineChart = 'LineChart',
  BarChart = 'BarChart',
  PieChart = 'PieChart',
}

export type TimeSeriesData = {
  name: string;
  value: number;
}[];

export type CategoricalData = {
  name: string;
  value: number;
}[];

export type KpiData = {
  value: number;
  change: number;
};

export type WidgetData = TimeSeriesData | CategoricalData | KpiData;

export type AlertCondition = 'above' | 'below';
export type NotificationChannel = 'in-app' | 'email';

export interface AlertConfig {
  enabled: boolean;
  condition: AlertCondition;
  threshold: number;
  channels: NotificationChannel[];
}

export interface WidgetConfig {
  id: string;
  type: WidgetType;
  title: string;
  gridSpan: number;
  alert?: AlertConfig;
}

export type Theme = 'light' | 'dark';

export interface Notification {
  id: string;
  widgetTitle: string;
  message: string;
  timestamp: Date;
  read: boolean;
}

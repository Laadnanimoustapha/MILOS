
import { WidgetConfig, WidgetType, AlertConfig } from './types';

export const WIDGET_DEFINITIONS: { type: WidgetType; name: string; defaultSpan: number }[] = [
  { type: WidgetType.KPI, name: 'KPI Card', defaultSpan: 1 },
  { type: WidgetType.LineChart, name: 'Line Chart', defaultSpan: 2 },
  { type: WidgetType.BarChart, name: 'Bar Chart', defaultSpan: 2 },
  { type: WidgetType.PieChart, name: 'Pie Chart', defaultSpan: 1 },
];

const defaultAlertConfig: AlertConfig = {
  enabled: false,
  condition: 'above',
  threshold: 10000,
  channels: ['in-app', 'email'],
};

export const SALES_TEMPLATE: WidgetConfig[] = [
  { id: 'sales-kpi-1', type: WidgetType.KPI, title: 'Total Revenue', gridSpan: 1, alert: { enabled: true, condition: 'above', threshold: 15000, channels: ['in-app', 'email'] } },
  { id: 'sales-kpi-2', type: WidgetType.KPI, title: 'New Customers', gridSpan: 1, alert: { ...defaultAlertConfig } },
  { id: 'sales-kpi-3', type: WidgetType.KPI, title: 'Avg. Order Value', gridSpan: 1, alert: { ...defaultAlertConfig } },
  { id: 'sales-kpi-4', type: WidgetType.KPI, title: 'Conversion Rate', gridSpan: 1, alert: { ...defaultAlertConfig } },
  { id: 'sales-line-1', type: WidgetType.LineChart, title: 'Revenue Over Time', gridSpan: 2, alert: { ...defaultAlertConfig } },
  { id: 'sales-bar-1', type: WidgetType.BarChart, title: 'Sales by Region', gridSpan: 2, alert: { ...defaultAlertConfig } },
  { id: 'sales-pie-1', type: WidgetType.PieChart, title: 'Product Category Breakdown', gridSpan: 1, alert: { ...defaultAlertConfig } },
];

export const MARKETING_TEMPLATE: WidgetConfig[] = [
  { id: 'mkt-kpi-1', type: WidgetType.KPI, title: 'Website Traffic', gridSpan: 1, alert: { ...defaultAlertConfig } },
  { id: 'mkt-kpi-2', type: WidgetType.KPI, title: 'Lead Generation', gridSpan: 1, alert: { ...defaultAlertConfig } },
  { id: 'mkt-kpi-3', type: WidgetType.KPI, title: 'Click-Through Rate', gridSpan: 1, alert: { ...defaultAlertConfig } },
  { id: 'mkt-kpi-4', type: WidgetType.KPI, title: 'Social Media Followers', gridSpan: 1, alert: { ...defaultAlertConfig } },
  { id: 'mkt-line-1', type: WidgetType.LineChart, title: 'Traffic by Source', gridSpan: 4, alert: { ...defaultAlertConfig } },
  { id: 'mkt-bar-1', type: WidgetType.BarChart, title: 'Campaign Performance', gridSpan: 2, alert: { ...defaultAlertConfig } },
  { id: 'mkt-pie-1', type: WidgetType.PieChart, title: 'Traffic Device Breakdown', gridSpan: 2, alert: { ...defaultAlertConfig } },
];
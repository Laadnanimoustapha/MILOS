
import React, { useState, useEffect, useRef } from 'react';
import { WidgetConfig, WidgetType, WidgetData, AlertConfig, NotificationChannel, KpiData } from '../types';
import { generateKpiData, generateTimeSeriesData, generateCategoricalData } from '../services/dataService';
import { getChartInsights } from '../services/geminiService';
import { Card } from './ui/Card';
import { KpiCard } from './charts/KpiCard';
import { LineChartComponent, BarChartComponent, PieChartComponent } from './charts/ChartComponents';
import { Button } from './ui/Button';
import { AlertSettingsModal } from './AlertSettingsModal';

interface WidgetWrapperProps {
  config: WidgetConfig;
  onRemove: (id: string) => void;
  onUpdateWidgetConfig: (id: string, updates: Partial<WidgetConfig>) => void;
  onTriggerAlert: (widgetTitle: string, message: string, channels: NotificationChannel[]) => void;
}

const WidgetSkeleton: React.FC = () => (
    <div className="animate-pulse flex flex-col h-full">
      <div className="flex-grow bg-gray-200 dark:bg-gray-700/50 rounded-md"></div>
      <div className="mt-4 h-4 bg-gray-200 dark:bg-gray-700/50 rounded w-3/4"></div>
      <div className="mt-2 h-4 bg-gray-200 dark:bg-gray-700/50 rounded w-1/2"></div>
    </div>
);

const SparkleIcon: React.FC = () => (
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4"><path d="M12 3L9.5 8.5L4 10l5.5 5.5L8 21l4-3 4 3-1.5-5.5L20 10l-5.5-1.5z"/></svg>
);

const AlertIcon: React.FC<{enabled?: boolean}> = ({ enabled }) => (
    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-2" viewBox="0 0 20 20" fill="currentColor">
        <path d="M10 2a6 6 0 00-6 6v3.586l-1.707 1.707A1 1 0 003 15h14a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z" />
    </svg>
);

const TrashIcon: React.FC = () => (
    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-2" viewBox="0 0 20 20" fill="currentColor">
        <path fillRule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clipRule="evenodd" />
    </svg>
);

const KebabMenuIcon: React.FC = () => (
    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
        <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
    </svg>
);

export const WidgetWrapper: React.FC<WidgetWrapperProps> = ({ config, onRemove, onUpdateWidgetConfig, onTriggerAlert }) => {
  const [data, setData] = useState<WidgetData | null>(null);
  const [insight, setInsight] = useState<string>('');
  const [isInsightLoading, setIsInsightLoading] = useState(false);
  const [isAlertModalOpen, setIsAlertModalOpen] = useState(false);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const alertConfigJson = JSON.stringify(config.alert);

  useEffect(() => {
    const timer = setTimeout(() => {
        let widgetData: WidgetData;
        switch (config.type) {
            case WidgetType.KPI:
                widgetData = generateKpiData();
                break;
            case WidgetType.LineChart:
                widgetData = generateTimeSeriesData();
                break;
            case WidgetType.BarChart:
                widgetData = generateCategoricalData();
                break;
            case WidgetType.PieChart:
                widgetData = generateCategoricalData(4);
                break;
            default:
                widgetData = [];
        }
        setData(widgetData);

        if (config.alert?.enabled && config.type === WidgetType.KPI) {
            const value = (widgetData as KpiData).value;
            const { condition, threshold, channels } = config.alert;
            let triggered = false;
            if (condition === 'above' && value > threshold) triggered = true;
            else if (condition === 'below' && value < threshold) triggered = true;
            
            if (triggered) {
                const formattedValue = new Intl.NumberFormat().format(value);
                const formattedThreshold = new Intl.NumberFormat().format(threshold);
                const message = `Value (${formattedValue}) went ${condition} threshold of ${formattedThreshold}.`;
                onTriggerAlert(config.title, message, channels);

                if (channels.includes('email')) {
                    console.log(`[Email Simulation] An email alert was sent for "${config.title}": ${message}`);
                }
            }
        }
    }, 500); // Simulate network latency
    return () => clearTimeout(timer);
  }, [config.type, config.id, config.title, alertConfigJson, onTriggerAlert]);
  
  // Close menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setIsMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleGetInsights = async () => {
    if (!data) return;
    setIsInsightLoading(true);
    setInsight('');
    const result = await getChartInsights(config.title, config.type, data);
    setInsight(result);
    setIsInsightLoading(false);
  };

  const handleSaveAlert = (alertConfig: AlertConfig) => {
    onUpdateWidgetConfig(config.id, { alert: alertConfig });
    setIsAlertModalOpen(false);
  }
  
  const renderContent = () => {
    if (!data) {
      return <WidgetSkeleton />;
    }
    switch (config.type) {
      case WidgetType.KPI: return <KpiCard data={data as any} />;
      case WidgetType.LineChart: return <LineChartComponent data={data as any} />;
      case WidgetType.BarChart: return <BarChartComponent data={data as any} />;
      case WidgetType.PieChart: return <PieChartComponent data={data as any} />;
      default: return <p>Unknown widget type</p>;
    }
  };

  return (
    <>
      <Card className={`col-span-1 md:col-span-${config.gridSpan} flex flex-col min-h-[280px]`}>
        <div className="flex justify-between items-start mb-4">
          <h3 className="font-semibold text-text-primary-light dark:text-text-primary-dark">{config.title}</h3>
          <div className="relative" ref={menuRef}>
            <Button variant="ghost" size="icon" onClick={() => setIsMenuOpen(prev => !prev)} className="h-6 w-6">
                <KebabMenuIcon />
            </Button>
            {isMenuOpen && (
                <div className="absolute top-full right-0 mt-2 w-48 bg-card-light dark:bg-card-dark border border-border-light dark:border-border-dark rounded-md shadow-lg z-10">
                    {config.type === WidgetType.KPI && (
                      <button onClick={() => { setIsAlertModalOpen(true); setIsMenuOpen(false); }} className={`flex items-center w-full px-4 py-2 text-sm text-left ${config.alert?.enabled ? 'text-primary-light dark:text-primary-dark' : 'text-text-primary-light dark:text-text-primary-dark'} hover:bg-background-light dark:hover:bg-border-dark`}>
                          <AlertIcon /> Set Alert
                      </button>
                    )}
                    <button onClick={() => { onRemove(config.id); setIsMenuOpen(false); }} className="flex items-center w-full px-4 py-2 text-sm text-red-500 hover:bg-background-light dark:hover:bg-border-dark">
                        <TrashIcon /> Remove Widget
                    </button>
                </div>
            )}
          </div>
        </div>
        <div className="flex-grow">
          {renderContent()}
        </div>
        {(config.type !== WidgetType.KPI && data) && (
          <div className="mt-4 pt-4 border-t border-border-light dark:border-border-dark">
            {isInsightLoading ? (
               <div className="flex items-center text-text-muted-light dark:text-text-muted-dark text-sm animate-pulse"><SparkleIcon/><span className="ml-2">Generating insights...</span></div>
            ) : insight ? (
              <div className="text-sm text-text-secondary-light dark:text-text-secondary-dark relative pl-4 italic before:content-[''] before:absolute before:left-0 before:top-0 before:h-full before:w-1 before:bg-primary-light/50 dark:before:bg-primary-dark/50 before:rounded">
                {insight}
              </div>
            ) : (
              <Button variant="ghost" size="sm" onClick={handleGetInsights}>
                <SparkleIcon/>
                Get AI Insights
              </Button>
            )}
          </div>
        )}
      </Card>
      {config.alert && (
        <AlertSettingsModal 
            isOpen={isAlertModalOpen}
            onClose={() => setIsAlertModalOpen(false)}
            widget={config}
            onSave={handleSaveAlert}
        />
      )}
    </>
  );
};

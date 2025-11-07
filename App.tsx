
import React, { useState, useEffect, useCallback, useRef } from 'react';
import { WidgetConfig, Theme, WidgetType, Notification, NotificationChannel } from './types';
import { Header } from './components/Header';
import { WidgetWrapper } from './components/WidgetWrapper';
import { AddWidgetModal } from './components/AddWidgetModal';
import { SALES_TEMPLATE, MARKETING_TEMPLATE } from './constants';
import html2canvas from 'html2canvas';
import { NotificationsPanel } from './components/NotificationsPanel';
import { Button } from './components/ui/Button';

const EmptyDashboard: React.FC<{onAddWidget: () => void; onLoadTemplate: () => void;}> = ({ onAddWidget, onLoadTemplate }) => (
    <div className="text-center py-20 border-2 border-dashed border-border-light dark:border-border-dark rounded-lg flex flex-col items-center">
        <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-text-muted-light dark:text-text-muted-dark mb-4">
          <rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/><path d="M9 21V9"/>
        </svg>
        <h2 className="text-xl font-semibold">Your Dashboard is Empty</h2>
        <p className="text-text-secondary-light dark:text-text-secondary-dark mt-2 max-w-sm">Get started by adding a new widget or loading a pre-built template to visualize your data.</p>
        <div className="flex gap-4 mt-6">
            <Button variant="secondary" onClick={onLoadTemplate}>Load a Template</Button>
            <Button variant="primary" onClick={onAddWidget}>Add a Widget</Button>
        </div>
    </div>
)

const App: React.FC = () => {
  const [widgets, setWidgets] = useState<WidgetConfig[]>(SALES_TEMPLATE);
  const [theme, setTheme] = useState<Theme>('light');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [isNotificationsPanelOpen, setIsNotificationsPanelOpen] = useState(false);
  const dashboardRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [theme]);

  const addWidget = (type: WidgetType, title: string, gridSpan: number) => {
    const newWidget: WidgetConfig = {
      id: `${type}-${Date.now()}`,
      type,
      title,
      gridSpan,
      alert: { enabled: false, condition: 'above', threshold: 10000, channels: ['in-app'] }
    };
    setWidgets(prevWidgets => [...prevWidgets, newWidget]);
    setIsModalOpen(false);
  };

  const removeWidget = useCallback((id: string) => {
    setWidgets(prevWidgets => prevWidgets.filter(widget => widget.id !== id));
  }, []);

  const updateWidgetConfig = useCallback((widgetId: string, updates: Partial<WidgetConfig>) => {
    setWidgets(currentWidgets =>
      currentWidgets.map(widget =>
        widget.id === widgetId ? { ...widget, ...updates } : widget
      )
    );
  }, []);

  const triggerAlert = useCallback((widgetTitle: string, message: string, channels: NotificationChannel[]) => {
    if (channels.includes('in-app')) {
      const newNotification: Notification = {
        id: Date.now().toString(),
        widgetTitle,
        message,
        timestamp: new Date(),
        read: false,
      };
      setNotifications(prev => [newNotification, ...prev].slice(0, 20)); // Keep last 20 notifications
    }
    // Note: Email simulation is now handled directly in WidgetWrapper.tsx
  }, []);

  const loadTemplate = (template: 'sales' | 'marketing' | 'clear') => {
    if (template === 'sales') setWidgets(SALES_TEMPLATE);
    else if (template === 'marketing') setWidgets(MARKETING_TEMPLATE);
    else if (template === 'clear') setWidgets([]);
    setIsNotificationsPanelOpen(false);
  };

  const exportDashboard = () => {
    if (dashboardRef.current) {
        html2canvas(dashboardRef.current, {
            useCORS: true,
            backgroundColor: theme === 'light' ? '#f8fafc' : '#020617'
        }).then(canvas => {
            const link = document.createElement('a');
            link.download = 'dashboard.png';
            link.href = canvas.toDataURL('image/png');
            link.click();
        });
    }
  };

  const handleMarkAsRead = (id: string) => {
    setNotifications(prev => prev.map(n => n.id === id ? {...n, read: true} : n));
  };
  
  const handleClearAll = () => {
    setNotifications([]);
    setIsNotificationsPanelOpen(false);
  };

  return (
    <div className="min-h-screen text-text-primary-light dark:text-text-primary-dark transition-colors duration-300">
      <Header
        onAddWidget={() => setIsModalOpen(true)}
        onLoadTemplate={loadTemplate}
        onExport={exportDashboard}
        theme={theme}
        setTheme={setTheme}
        notifications={notifications}
        onToggleNotifications={() => setIsNotificationsPanelOpen(prev => !prev)}
      />
      <div className="relative">
        <NotificationsPanel 
          isOpen={isNotificationsPanelOpen}
          notifications={notifications}
          onMarkAsRead={handleMarkAsRead}
          onClearAll={handleClearAll}
          onClose={() => setIsNotificationsPanelOpen(false)}
        />
      </div>
      <main className="container mx-auto p-4 sm:p-8">
        {widgets.length > 0 ? (
          <div ref={dashboardRef} className="grid grid-cols-1 md:grid-cols-4 gap-6">
            {widgets.map(config => (
              <WidgetWrapper 
                key={config.id} 
                config={config} 
                onRemove={removeWidget} 
                onUpdateWidgetConfig={updateWidgetConfig}
                onTriggerAlert={triggerAlert}
              />
            ))}
          </div>
        ) : (
            <EmptyDashboard onAddWidget={() => setIsModalOpen(true)} onLoadTemplate={() => loadTemplate('sales')} />
        )}
      </main>
      <AddWidgetModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onAddWidget={addWidget}
      />
    </div>
  );
};

export default App;

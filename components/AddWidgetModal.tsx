
import React, { useState } from 'react';
import { WidgetType } from '../types';
import { WIDGET_DEFINITIONS } from '../constants';
import { Card } from './ui/Card';
import { Button } from './ui/Button';

interface AddWidgetModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAddWidget: (type: WidgetType, title: string, gridSpan: number) => void;
}

interface WidgetOption {
    type: WidgetType;
    name: string;
    defaultSpan: number;
    icon: React.ReactNode;
    description: string;
}

const WIDGET_OPTIONS: WidgetOption[] = [
    { type: WidgetType.KPI, name: 'KPI Card', defaultSpan: 1, icon: <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg>, description: 'Display a single key metric.' },
    { type: WidgetType.LineChart, name: 'Line Chart', defaultSpan: 2, icon: <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg>, description: 'Track data over a time series.' },
    // Fix: Corrected typo from DidgetType to WidgetType
    { type: WidgetType.BarChart, name: 'Bar Chart', defaultSpan: 2, icon: <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 3v18h18"/><path d="M18 17V9"/><path d="M13 17V5"/><path d="M8 17v-3"/></svg>, description: 'Compare values across categories.' },
    { type: WidgetType.PieChart, name: 'Pie Chart', defaultSpan: 1, icon: <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>, description: 'Show proportional data.' },
];

export const AddWidgetModal: React.FC<AddWidgetModalProps> = ({ isOpen, onClose, onAddWidget }) => {
  const [selectedWidget, setSelectedWidget] = useState<WidgetOption | null>(null);
  const [title, setTitle] = useState('');

  if (!isOpen) return null;

  const handleSelectWidget = (widget: WidgetOption) => {
    setSelectedWidget(widget);
    setTitle(`New ${widget.name}`);
  }

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (selectedWidget && title) {
      onAddWidget(selectedWidget.type, title, selectedWidget.defaultSpan);
      handleClose();
    }
  };

  const handleClose = () => {
    setSelectedWidget(null);
    setTitle('');
    onClose();
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 transition-opacity duration-300" onClick={handleClose}>
      <Card className="w-full max-w-lg" onClick={(e) => e.stopPropagation()}>
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-lg font-semibold text-text-primary-light dark:text-text-primary-dark">
            {selectedWidget ? `Configure ${selectedWidget.name}` : 'Add New Widget'}
          </h2>
          <button onClick={handleClose} className="text-text-secondary-light dark:text-text-secondary-dark hover:text-red-500 font-bold text-2xl">&times;</button>
        </div>
        
        {!selectedWidget ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {WIDGET_OPTIONS.map((widget) => (
              <button
                key={widget.type}
                onClick={() => handleSelectWidget(widget)}
                className="p-4 border border-border-light dark:border-border-dark rounded-lg hover:bg-background-light dark:hover:bg-border-dark transition-colors text-left flex items-start gap-4"
              >
                <div className="text-primary-light dark:text-primary-dark mt-1">{widget.icon}</div>
                <div>
                    <h3 className="font-semibold text-text-primary-light dark:text-text-primary-dark">{widget.name}</h3>
                    <p className="text-sm text-text-secondary-light dark:text-text-secondary-dark mt-1">{widget.description}</p>
                </div>
              </button>
            ))}
          </div>
        ) : (
            <form onSubmit={handleAdd} className="space-y-4">
                <div>
                    <label htmlFor="widget-title" className="block text-sm font-medium text-text-secondary-light dark:text-text-secondary-dark mb-2">Widget Title</label>
                    <input 
                        id="widget-title"
                        type="text"
                        value={title}
                        onChange={(e) => setTitle(e.target.value)}
                        autoFocus
                        className="w-full bg-background-light dark:bg-card-dark border border-border-light dark:border-border-dark rounded-md px-3 py-2 text-sm focus:ring-2 focus:ring-ring-light dark:focus:ring-ring-dark focus:border-primary-light"
                    />
                </div>
                <div className="flex justify-end gap-2 pt-4">
                    <Button type="button" variant="secondary" onClick={() => setSelectedWidget(null)}>Back</Button>
                    <Button type="submit" variant="primary">Add Widget</Button>
                </div>
            </form>
        )}
      </Card>
    </div>
  );
};


import React, { useState, useEffect } from 'react';
import { WidgetConfig, AlertConfig, AlertCondition, NotificationChannel } from '../types';
import { Card } from './ui/Card';
import { Button } from './ui/Button';
import { Switch } from './ui/Switch';

interface AlertSettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  widget: WidgetConfig;
  onSave: (alertConfig: AlertConfig) => void;
}

export const AlertSettingsModal: React.FC<AlertSettingsModalProps> = ({ isOpen, onClose, widget, onSave }) => {
  const [alertConfig, setAlertConfig] = useState<AlertConfig>(
    widget.alert || { enabled: false, condition: 'above', threshold: 0, channels: [] }
  );

  useEffect(() => {
    setAlertConfig(widget.alert || { enabled: false, condition: 'above', threshold: 0, channels: [] });
  }, [widget.alert, isOpen]);

  if (!isOpen) return null;

  const handleChannelChange = (channel: NotificationChannel, checked: boolean) => {
    const newChannels = checked
      ? [...alertConfig.channels, channel]
      : alertConfig.channels.filter(c => c !== channel);
    setAlertConfig(prev => ({ ...prev, channels: newChannels }));
  };

  const handleSave = () => {
    onSave(alertConfig);
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
      <Card className="w-full max-w-md" onClick={(e) => e.stopPropagation()}>
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-lg font-semibold text-text-primary-light dark:text-text-primary-dark">Alert Settings for "{widget.title}"</h2>
          <button onClick={onClose} className="text-text-secondary-light dark:text-text-secondary-dark hover:text-red-500 font-bold text-2xl">&times;</button>
        </div>
        
        <div className="space-y-6">
          <div className="flex items-center justify-between p-4 border border-border-light dark:border-border-dark rounded-lg">
            <label htmlFor="enable-alert" className="font-medium text-text-primary-light dark:text-text-primary-dark">Enable Alert</label>
            <Switch id="enable-alert" checked={alertConfig.enabled} onChange={(checked) => setAlertConfig(prev => ({...prev, enabled: checked}))} />
          </div>

          {alertConfig.enabled && (
            <>
              <div>
                <label htmlFor="condition" className="block text-sm font-medium text-text-secondary-light dark:text-text-secondary-dark mb-2">Condition</label>
                <div className="flex gap-2">
                  <select
                    id="condition"
                    value={alertConfig.condition}
                    onChange={(e) => setAlertConfig(prev => ({ ...prev, condition: e.target.value as AlertCondition }))}
                    className="w-1/2 bg-background-light dark:bg-card-dark border border-border-light dark:border-border-dark rounded-md px-3 py-2 text-sm focus:ring-2 focus:ring-ring-light dark:focus:ring-ring-dark focus:border-primary-light"
                  >
                    <option value="above">Value is above</option>
                    <option value="below">Value is below</option>
                  </select>
                  <input
                    type="number"
                    value={alertConfig.threshold}
                    onChange={(e) => setAlertConfig(prev => ({ ...prev, threshold: Number(e.target.value) }))}
                    placeholder="Threshold value"
                    className="w-1/2 bg-background-light dark:bg-card-dark border border-border-light dark:border-border-dark rounded-md px-3 py-2 text-sm focus:ring-2 focus:ring-ring-light dark:focus:ring-ring-dark focus:border-primary-light"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-text-secondary-light dark:text-text-secondary-dark mb-2">Notify Me Via</label>
                <div className="space-y-2">
                  <div className="flex items-center">
                    <input type="checkbox" id="in-app" checked={alertConfig.channels.includes('in-app')} onChange={(e) => handleChannelChange('in-app', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-primary-light focus:ring-primary-light" />
                    <label htmlFor="in-app" className="ml-3 block text-sm text-text-primary-light dark:text-text-primary-dark">In-app Notification</label>
                  </div>
                  <div className="flex items-center">
                    <input type="checkbox" id="email" checked={alertConfig.channels.includes('email')} onChange={(e) => handleChannelChange('email', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-primary-light focus:ring-primary-light" />
                    <label htmlFor="email" className="ml-3 block text-sm text-text-primary-light dark:text-text-primary-dark">Email</label>
                  </div>
                </div>
              </div>
            </>
          )}

          <div className="flex justify-end gap-2 pt-4 border-t border-border-light dark:border-border-dark">
            <Button variant="secondary" onClick={onClose}>Cancel</Button>
            <Button variant="primary" onClick={handleSave}>Save Changes</Button>
          </div>
        </div>
      </Card>
    </div>
  );
};
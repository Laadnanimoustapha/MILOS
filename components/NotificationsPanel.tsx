
import React from 'react';
import { Notification } from '../types';
import { Card } from './ui/Card';
import { Button } from './ui/Button';

interface NotificationsPanelProps {
  isOpen: boolean;
  notifications: Notification[];
  onMarkAsRead: (id: string) => void;
  onClearAll: () => void;
  onClose: () => void;
}

const timeSince = (date: Date): string => {
  const seconds = Math.floor((new Date().getTime() - date.getTime()) / 1000);
  let interval = seconds / 31536000;
  if (interval > 1) return Math.floor(interval) + "y ago";
  interval = seconds / 2592000;
  if (interval > 1) return Math.floor(interval) + "mo ago";
  interval = seconds / 86400;
  if (interval > 1) return Math.floor(interval) + "d ago";
  interval = seconds / 3600;
  if (interval > 1) return Math.floor(interval) + "h ago";
  interval = seconds / 60;
  if (interval > 1) return Math.floor(interval) + "m ago";
  return Math.floor(seconds) + "s ago";
};

export const NotificationsPanel: React.FC<NotificationsPanelProps> = ({ isOpen, notifications, onMarkAsRead, onClearAll, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="absolute top-full right-4 mt-2 z-30 w-full max-w-sm">
      <Card className="shadow-2xl">
        <div className="flex justify-between items-center mb-4">
          <h3 className="font-semibold text-text-primary-light dark:text-text-primary-dark">Notifications</h3>
          {notifications.length > 0 && <Button variant="ghost" size="sm" onClick={onClearAll}>Clear All</Button>}
        </div>
        <div className="max-h-96 overflow-y-auto pr-2 -mr-4">
          {notifications.length === 0 ? (
            <div className="text-center py-8 text-text-secondary-light dark:text-text-secondary-dark flex flex-col items-center">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
              <p className="mt-4">No new notifications.</p>
            </div>
          ) : (
            <ul className="space-y-2">
              {notifications.map(n => (
                <li key={n.id} className="p-3 rounded-lg flex items-start gap-3">
                    {!n.read && <span className="flex-shrink-0 mt-1.5 h-2 w-2 rounded-full bg-primary-light dark:bg-primary-dark"></span>}
                    <div className={n.read ? 'pl-5' : ''}>
                      <p className="font-semibold text-sm text-text-primary-light dark:text-text-primary-dark">{n.widgetTitle}</p>
                      <p className="text-sm text-text-secondary-light dark:text-text-secondary-dark mt-1">{n.message}</p>
                      <div className="flex items-center gap-4 mt-2">
                        <p className="text-xs text-text-muted-light/70 dark:text-text-muted-dark/70">{timeSince(n.timestamp)}</p>
                        {!n.read && (
                            <button onClick={() => onMarkAsRead(n.id)} className="text-xs font-semibold text-primary-light dark:text-primary-dark hover:underline">Mark as read</button>
                        )}
                      </div>
                    </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Card>
    </div>
  );
};
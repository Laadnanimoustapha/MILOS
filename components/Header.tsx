
import React, { useState, useEffect, useRef } from 'react';
import { Button } from './ui/Button';
import { Theme, Notification } from '../types';

interface HeaderProps {
  onAddWidget: () => void;
  onLoadTemplate: (template: 'sales' | 'marketing' | 'clear') => void;
  onExport: () => void;
  theme: Theme;
  setTheme: (theme: Theme) => void;
  notifications: Notification[];
  onToggleNotifications: () => void;
}

const SunIcon = () => (
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg>
);
const MoonIcon = () => (
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>
);
const PlusIcon = () => (
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4"><path d="M5 12h14"/><path d="M12 5v14"/></svg>
);
const BellIcon = () => (
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
);

const TemplateDropdown: React.FC<{onLoadTemplate: (template: 'sales' | 'marketing' | 'clear') => void}> = ({ onLoadTemplate }) => {
    const [isOpen, setIsOpen] = useState(false);
    const dropdownRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
          if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
            setIsOpen(false);
          }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    const handleSelect = (template: 'sales' | 'marketing' | 'clear') => {
        onLoadTemplate(template);
        setIsOpen(false);
    }
    
    return (
        <div className="relative" ref={dropdownRef}>
            <Button variant="secondary" onClick={() => setIsOpen(prev => !prev)}>
                Load Template
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </Button>
            {isOpen && (
                <div className="absolute top-full right-0 mt-2 w-48 bg-card-light dark:bg-card-dark border border-border-light dark:border-border-dark rounded-md shadow-lg z-30">
                    <a href="#" onClick={(e) => { e.preventDefault(); handleSelect('sales'); }} className="block px-4 py-2 text-sm text-text-primary-light dark:text-text-primary-dark hover:bg-background-light dark:hover:bg-border-dark">Sales</a>
                    <a href="#" onClick={(e) => { e.preventDefault(); handleSelect('marketing'); }} className="block px-4 py-2 text-sm text-text-primary-light dark:text-text-primary-dark hover:bg-background-light dark:hover:bg-border-dark">Marketing</a>
                    <div className="border-t border-border-light dark:border-border-dark my-1"></div>
                    <a href="#" onClick={(e) => { e.preventDefault(); handleSelect('clear'); }} className="block px-4 py-2 text-sm text-red-500 hover:bg-background-light dark:hover:bg-border-dark">Clear All</a>
                </div>
            )}
        </div>
    )
}

export const Header: React.FC<HeaderProps> = ({ onAddWidget, onLoadTemplate, onExport, theme, setTheme, notifications, onToggleNotifications }) => {
  const unreadCount = notifications.filter(n => !n.read).length;

  return (
    <header className="p-4 bg-card-light/80 dark:bg-card-dark/80 backdrop-blur-sm border-b border-border-light dark:border-border-dark sticky top-0 z-20">
      <div className="container mx-auto flex flex-wrap justify-between items-center gap-4">
        <h1 className="text-xl font-bold text-text-primary-light dark:text-text-primary-dark">Dashboard Pro</h1>
        <div className="flex flex-wrap items-center gap-2">
            <TemplateDropdown onLoadTemplate={onLoadTemplate} />
            <Button variant="secondary" onClick={onExport}>Export PNG</Button>
            <Button variant="primary" onClick={onAddWidget}><PlusIcon/> Add Widget</Button>
            <div className="w-px h-6 bg-border-light dark:bg-border-dark mx-2"></div>
             <Button variant="ghost" size="icon" onClick={onToggleNotifications} className="relative">
                <BellIcon />
                {unreadCount > 0 && (
                    <span className="absolute top-1 right-1 flex h-3 w-3 items-center justify-center">
                        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-red-400 opacity-75"></span>
                        <span className="relative inline-flex h-2 w-2 rounded-full bg-red-500"></span>
                    </span>
                )}
            </Button>
            <Button variant="ghost" size="icon" onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
                {theme === 'light' ? <MoonIcon/> : <SunIcon/>}
            </Button>
        </div>
      </div>
    </header>
  );
};
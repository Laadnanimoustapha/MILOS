
import React from 'react';

interface SwitchProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  id: string;
}

export const Switch: React.FC<SwitchProps> = ({ checked, onChange, id }) => {
  return (
    <button
      id={id}
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={`${
        checked ? 'bg-primary-light dark:bg-primary-dark' : 'bg-gray-200 dark:bg-gray-600'
      } relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-primary-light focus:ring-offset-2 dark:focus:ring-offset-card-light dark:focus:ring-offset-card-dark`}
    >
      <span
        aria-hidden="true"
        className={`${
          checked ? 'translate-x-5' : 'translate-x-0'
        } pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out`}
      />
    </button>
  );
};

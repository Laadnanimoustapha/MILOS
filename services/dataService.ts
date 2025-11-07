
import { KpiData, TimeSeriesData, CategoricalData } from '../types';

const getRandom = (min: number, max: number) => Math.random() * (max - min) + min;

export const generateKpiData = (): KpiData => ({
  value: Math.floor(getRandom(1000, 100000)),
  change: getRandom(-15, 15),
});

export const generateTimeSeriesData = (points: number = 12): TimeSeriesData => {
  const data: TimeSeriesData = [];
  for (let i = 0; i < points; i++) {
    data.push({
      name: `Month ${i + 1}`,
      value: Math.floor(getRandom(100, 1000)),
    });
  }
  return data;
};

export const generateCategoricalData = (categories: number = 5): CategoricalData => {
  const data: CategoricalData = [];
  const categoryNames = ['North', 'South', 'East', 'West', 'Central', 'Online', 'Retail'];
  for (let i = 0; i < categories; i++) {
    data.push({
      name: categoryNames[i % categoryNames.length],
      value: Math.floor(getRandom(50, 500)),
    });
  }
  return data;
};

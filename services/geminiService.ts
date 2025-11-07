
import { GoogleGenAI } from "@google/genai";
import { WidgetData, WidgetType } from '../types';

const API_KEY = process.env.API_KEY;

if (!API_KEY) {
  console.warn("API_KEY environment variable not set. Gemini features will be disabled.");
}

const ai = new GoogleGenAI({ apiKey: API_KEY });

export const getChartInsights = async (title: string, type: WidgetType, data: WidgetData): Promise<string> => {
  if (!API_KEY) {
    return Promise.resolve("AI features are disabled. Please set your API_KEY.");
  }

  const dataString = JSON.stringify(data, null, 2);
  const prompt = `
    You are a data analyst assistant.
    Analyze the following data for a chart titled "${title}" of type "${type}".
    Provide a concise, insightful summary (2-3 sentences) in plain language.
    Focus on the key takeaway or trend. Do not start with "This chart shows..." or "The data indicates...". Directly state the insight.

    Data:
    ${dataString}
  `;

  try {
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: prompt,
    });
    return response.text;
  } catch (error) {
    console.error("Error generating insights:", error);
    return "Could not generate insights at this time.";
  }
};

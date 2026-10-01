'use client';

import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Compass, AlertCircle } from 'lucide-react';
import { Alert, AlertTitle, AlertDescription } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';

export default function CompassPage() {
  const [heading, setHeading] = useState<number | null>(null);
  const [permissionState, setPermissionState] = useState<'granted' | 'denied' | 'prompt'>('prompt');

  const handleOrientation = useCallback((event: DeviceOrientationEvent) => {
    let newHeading: number | null = null;
    // For iOS devices
    if ((event as any).webkitCompassHeading) {
      newHeading = (event as any).webkitCompassHeading;
    } 
    // Standard API
    else if (event.alpha !== null) {
      newHeading = 360 - event.alpha;
    }
    
    if (newHeading !== null) {
      // Normalize to 0-360
      newHeading = (newHeading + 360) % 360;
      setHeading(newHeading);
    }
  }, []);

  const requestPermission = useCallback(async () => {
    if (typeof (DeviceOrientationEvent as any).requestPermission !== 'function') {
      // Should not happen if button is shown, but as a fallback
      setPermissionState('denied');
      return;
    }
    try {
      const state = await (DeviceOrientationEvent as any).requestPermission();
      if (state === 'granted') {
        setPermissionState('granted');
        window.addEventListener('deviceorientation', handleOrientation);
      } else {
        setPermissionState('denied');
      }
    } catch (error) {
      console.error('Device orientation permission request failed', error);
      setPermissionState('denied');
    }
  }, [handleOrientation]);

  useEffect(() => {
    if (typeof window.DeviceOrientationEvent === 'undefined') {
        setPermissionState('denied'); // No sensor support
        return;
    }
    
    if (typeof (DeviceOrientationEvent as any).requestPermission === 'function') {
        // iOS 13+ device, requires user interaction
        setPermissionState('prompt');
    } else {
        // Non-iOS device, permission is implicit or already granted
        setPermissionState('granted');
        window.addEventListener('deviceorientation', handleOrientation);
    }

    return () => {
      window.removeEventListener('deviceorientation', handleOrientation);
    };
  }, [handleOrientation]);

  return (
    <div className="max-w-md mx-auto">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Compass className="text-accent" />
            Digital Compass
          </CardTitle>
          <CardDescription>
            Your vessel's current magnetic heading.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col items-center justify-center space-y-6 min-h-[350px]">
          {permissionState === 'denied' && (
            <Alert variant="destructive">
              <AlertCircle className="h-4 w-4" />
              <AlertTitle>Sensor Access Denied</AlertTitle>
              <AlertDescription>
                Device orientation access is needed to display the compass. Please check your browser settings.
              </AlertDescription>
            </Alert>
          )}

          {permissionState === 'prompt' && (
             <div className="text-center space-y-4">
                 <p className="text-muted-foreground">This feature requires access to your device's motion sensors.</p>
                <Button onClick={requestPermission}>Grant Permission</Button>
            </div>
          )}

          {permissionState === 'granted' && (
            <>
              <div className="relative w-64 h-64">
                {/* Compass Rose */}
                <svg viewBox="0 0 200 200" className="w-full h-full">
                  <circle cx="100" cy="100" r="95" fill="hsl(var(--secondary))" stroke="hsl(var(--border))" strokeWidth="2" />
                  {/* Cardinal directions */}
                  <text x="100" y="25" textAnchor="middle" fill="hsl(var(--foreground))" fontSize="20" fontWeight="bold">N</text>
                  <text x="100" y="185" textAnchor="middle" fill="hsl(var(--foreground))" fontSize="20" fontWeight="bold">S</text>
                  <text x="15" y="105" textAnchor="middle" fill="hsl(var(--foreground))" fontSize="20" fontWeight="bold">W</text>
                  <text x="185" y="105" textAnchor="middle" fill="hsl(var(--foreground))" fontSize="20" fontWeight="bold">E</text>
                  {/* Ticks */}
                  {[...Array(36)].map((_, i) => (
                    <line key={i} x1="100" y1="10" x2="100" y2={i % 9 === 0 ? "30" : "20"} stroke="hsl(var(--muted-foreground))" strokeWidth="2" transform={`rotate(${i * 10}, 100, 100)`} />
                  ))}
                </svg>

                {/* Needle */}
                <div
                  className="absolute inset-0 transition-transform duration-500"
                  style={{ transform: `rotate(${heading || 0}deg)` }}
                >
                  <svg viewBox="0 0 200 200" className="w-full h-full">
                      {/* Red part of needle */}
                      <polygon points="100,10 105,100 95,100" fill="hsl(var(--destructive))" />
                      {/* Grey part of needle */}
                      <polygon points="100,190 105,100 95,100" fill="hsl(var(--muted-foreground))" />
                      <circle cx="100" cy="100" r="5" fill="hsl(var(--accent))" />
                  </svg>
                </div>
              </div>

              <div className="text-center">
                <p className="text-muted-foreground">Heading</p>
                <p className="text-5xl font-bold font-mono">
                  {heading !== null ? `${Math.round(heading)}°` : '...'}
                </p>
              </div>
            </>
          )}

        </CardContent>
      </Card>
    </div>
  );
}

'use client';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Alert, AlertTitle, AlertDescription } from '@/components/ui/alert';
import { Separator } from '@/components/ui/separator';
import { MapPin, Wind, Gauge, Droplets, Ship, WifiOff, AlertCircle } from 'lucide-react';
import { useVesselData } from '@/hooks/use-vessel-data';
import { Progress } from '@/components/ui/progress';
import { useState, useEffect } from 'react';
import { Skeleton } from '@/components/ui/skeleton';

// Define default safety thresholds for warnings, used if no profile is set
const DEFAULT_THRESHOLDS = {
    highEngineTemp: 100,    // Celsius
    cautionEngineTemp: 95,   // Celsius
    lowOilPressure: 2.0,    // bar
    cautionOilPressure: 2.5, // bar
    lowFuelLevel: 15,       // percent
    cautionFuelLevel: 25,   // percent
};

const LOCAL_STORAGE_KEY_PROFILE = 'vesselProfile';

function VesselDashboardSkeleton() {
  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <Card className="bg-card/50 backdrop-blur-sm">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-2xl">
            <Skeleton className="h-8 w-8" />
            <Skeleton className="h-7 w-48" />
          </CardTitle>
          <CardDescription>
            <Skeleton className="h-5 w-3/4" />
          </CardDescription>
        </CardHeader>
      </Card>

      <Alert>
        <Skeleton className="h-4 w-4" />
        <div className="ml-7 space-y-1">
            <AlertTitle><Skeleton className="h-5 w-64" /></AlertTitle>
            <AlertDescription>
            <Skeleton className="h-4 w-full" />
            </AlertDescription>
        </div>
      </Alert>

      <div className='grid grid-cols-1 lg:grid-cols-3 gap-6'>
        {/* Left Column */}
        <div className='lg:col-span-1 space-y-6'>
          <Card>
            <CardHeader>
              <CardTitle className='flex items-center gap-2'><MapPin/> Navigation</CardTitle>
            </CardHeader>
            <CardContent className='space-y-4'>
              <div className='flex justify-between items-baseline'>
                <span className='text-muted-foreground'>Position</span>
                <Skeleton className="h-5 w-40" />
              </div>
              <Separator/>
              <div className='grid grid-cols-2 gap-4'>
                  <div>
                     <p className='text-muted-foreground text-sm'>SOG</p>
                     <Skeleton className="h-8 w-20 mt-1" />
                  </div>
                   <div>
                     <p className='text-muted-foreground text-sm'>COG</p>
                     <Skeleton className="h-8 w-20 mt-1" />
                  </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className='flex items-center gap-2'><Wind/> Wind Data</CardTitle>
            </CardHeader>
            <CardContent className='space-y-4'>
              <div className='grid grid-cols-2 gap-4'>
                  <div>
                     <p className='text-muted-foreground text-sm'>Speed</p>
                     <Skeleton className="h-8 w-24 mt-1" />
                  </div>
                   <div>
                     <p className='text-muted-foreground text-sm'>Direction</p>
                     <Skeleton className="h-8 w-24 mt-1" />
                  </div>
              </div>
            </CardContent>
          </Card>
        </div>
        
        {/* Center Column */}
        <div className='lg:col-span-1 space-y-6'>
             <Card className='h-full'>
                <CardHeader>
                    <CardTitle className='flex items-center gap-2'><Gauge/> Engine Systems</CardTitle>
                </CardHeader>
                <CardContent className='flex flex-col justify-around h-full space-y-4'>
                     <div className='text-center'>
                         <p className='text-muted-foreground'>RPM</p>
                         <Skeleton className="h-12 w-32 mx-auto mt-1" />
                     </div>
                     <Separator />
                      <div className='grid grid-cols-2 gap-4 text-center'>
                          <div>
                             <p className='text-muted-foreground text-sm'>Temperature</p>
                             <Skeleton className="h-8 w-20 mx-auto mt-1" />
                          </div>
                           <div>
                             <p className='text-muted-foreground text-sm'>Oil Pressure</p>
                             <Skeleton className="h-8 w-20 mx-auto mt-1" />
                          </div>
                      </div>
                </CardContent>
            </Card>
        </div>

        {/* Right Column */}
        <div className='lg:col-span-1 space-y-6'>
          <Card>
             <CardHeader>
                <CardTitle className='flex items-center gap-2'><Droplets/> Tank Levels</CardTitle>
            </CardHeader>
             <CardContent className='space-y-6 pt-2'>
                 <div>
                     <div className='mb-2 flex justify-between'>
                         <span className='text-muted-foreground'>Fuel</span>
                         <Skeleton className="h-4 w-10" />
                     </div>
                     <Skeleton className="h-6 w-full" />
                 </div>
                  <div>
                      <div className='mb-2 flex justify-between'>
                         <span className='text-muted-foreground'>Water</span>
                         <Skeleton className="h-4 w-10" />
                      </div>
                      <Skeleton className="h-6 w-full" />
                 </div>
             </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}


export default function VesselDashboardPage() {
    const vesselData = useVesselData();
    const [thresholds, setThresholds] = useState(DEFAULT_THRESHOLDS);
    const [isMounted, setIsMounted] = useState(false);

    useEffect(() => {
        setIsMounted(true);
        try {
            const savedProfile = localStorage.getItem(LOCAL_STORAGE_KEY_PROFILE);
            if (savedProfile) {
                const profile = JSON.parse(savedProfile);
                const isMetric = !profile.units || profile.units === 'metric';

                // Use profile values or defaults
                let highTemp = profile.alarmHighEngineTemp || (isMetric ? 100 : 212);
                let lowPressure = profile.alarmLowOilPressure || (isMetric ? 2.0 : 29);
                let lowFuel = profile.alarmLowFuelLevel || 15;

                // Convert to metric if necessary, as data stream is in metric
                if (!isMetric) {
                    highTemp = (highTemp - 32) * 5 / 9; // F to C
                    lowPressure = lowPressure / 14.504; // psi to bar
                }
                
                setThresholds({
                    highEngineTemp: highTemp,
                    cautionEngineTemp: highTemp * 0.95, // 95% of high temp as caution
                    lowOilPressure: lowPressure,
                    cautionOilPressure: lowPressure * 1.25, // 125% of low pressure as caution
                    lowFuelLevel: lowFuel,
                    cautionFuelLevel: lowFuel + 10, // Caution at 10% above low
                });
            }
        } catch (e) {
            console.error("Could not load thresholds from profile, using defaults.", e);
            setThresholds(DEFAULT_THRESHOLDS);
        }
    }, []);

    if (!vesselData || !isMounted) {
        return <VesselDashboardSkeleton />;
    }

    const { navigation, engine, tanks, wind } = vesselData;
    
    const alerts = [];
    if (engine.temperature > thresholds.highEngineTemp) {
        alerts.push(`High Engine Temp: ${engine.temperature.toFixed(1)}°C`);
    }
    if (engine.oilPressure < thresholds.lowOilPressure) {
        alerts.push(`Low Oil Pressure: ${engine.oilPressure.toFixed(1)} bar`);
    }
    if (tanks.fuel < thresholds.lowFuelLevel) {
        alerts.push(`Low Fuel: ${tanks.fuel.toFixed(0)}%`);
    }

    const tempColor = engine.temperature > thresholds.highEngineTemp
        ? 'text-destructive animate-pulse' 
        : engine.temperature > thresholds.cautionEngineTemp
            ? 'text-chart-4' 
            : '';
            
    const pressureColor = engine.oilPressure < thresholds.lowOilPressure
        ? 'text-destructive animate-pulse'
        : engine.oilPressure < thresholds.cautionOilPressure
            ? 'text-chart-4'
            : '';
            
    const fuelTextColor = tanks.fuel < thresholds.lowFuelLevel
        ? 'text-destructive'
        : tanks.fuel < thresholds.cautionFuelLevel
            ? 'text-chart-4'
            : '';

    const fuelProgressClass = tanks.fuel < thresholds.lowFuelLevel
        ? '[&>div]:bg-destructive'
        : tanks.fuel < thresholds.cautionFuelLevel
            ? '[&>div]:bg-chart-4'
            : '';


    return (
        <div className="max-w-7xl mx-auto space-y-6">
            <Card className="bg-card/50 backdrop-blur-sm">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-2xl">
                        <Ship className="text-accent" />
                        Starship Bridge
                    </CardTitle>
                    <CardDescription>
                        Real-time data from vessel systems. Simulating data from BlueOS / ArduPilot.
                    </CardDescription>
                </CardHeader>
            </Card>

            {/* Alerts Section */}
            {alerts.length > 0 && (
                <Alert variant="destructive" className='animate-pulse'>
                    <AlertCircle className="h-4 w-4" />
                    <AlertTitle>CRITICAL ALERTS</AlertTitle>
                    <AlertDescription>
                        <ul className="list-disc list-inside">
                           {alerts.map((alert, i) => <li key={i}>{alert}</li>)}
                        </ul>
                    </AlertDescription>
                </Alert>
            )}
            
            {alerts.length === 0 && (
                 <Alert>
                    <WifiOff className="h-4 w-4" />
                    <AlertTitle>Simulation Mode Active | All Systems Nominal</AlertTitle>
                    <AlertDescription>
                        This dashboard is displaying simulated data. Connect to a WebSocket data source for live information.
                    </AlertDescription>
                </Alert>
            )}


            <div className='grid grid-cols-1 lg:grid-cols-3 gap-6'>

                {/* Left Column: Navigation & Wind */}
                <div className='lg:col-span-1 space-y-6'>
                    <Card>
                         <CardHeader>
                            <CardTitle className='flex items-center gap-2'><MapPin/> Navigation</CardTitle>
                        </CardHeader>
                         <CardContent className='space-y-4'>
                             <div className='flex justify-between items-baseline'>
                                 <span className='text-muted-foreground'>Position</span>
                                 <span className='font-mono text-lg'>{navigation.lat.toFixed(5)}, {navigation.lon.toFixed(5)}</span>
                             </div>
                              <Separator/>
                              <div className='grid grid-cols-2 gap-4'>
                                  <div>
                                     <p className='text-muted-foreground text-sm'>SOG</p>
                                     <p className='font-mono text-2xl'>{navigation.sog.toFixed(1)} <span className='text-sm text-muted-foreground'>kts</span></p>
                                  </div>
                                   <div>
                                     <p className='text-muted-foreground text-sm'>COG</p>
                                     <p className='font-mono text-2xl'>{navigation.cog.toFixed(0)}°</p>
                                  </div>
                              </div>
                         </CardContent>
                    </Card>
                    <Card>
                         <CardHeader>
                            <CardTitle className='flex items-center gap-2'><Wind/> Wind Data</CardTitle>
                        </CardHeader>
                         <CardContent className='space-y-4'>
                              <div className='grid grid-cols-2 gap-4'>
                                  <div>
                                     <p className='text-muted-foreground text-sm'>Speed</p>
                                     <p className='font-mono text-2xl'>{wind.speed.toFixed(1)} <span className='text-sm text-muted-foreground'>kts</span></p>
                                  </div>
                                   <div>
                                     <p className='text-muted-foreground text-sm'>Direction</p>
                                     <p className='font-mono text-2xl'>{wind.direction.toFixed(0)}° <span className='text-sm text-muted-foreground'>Rel</span></p>
                                  </div>
                              </div>
                         </CardContent>
                    </Card>
                </div>
                
                {/* Center Column: Engine */}
                <div className='lg:col-span-1 space-y-6'>
                     <Card className='h-full'>
                         <CardHeader>
                            <CardTitle className='flex items-center gap-2'><Gauge/> Engine Systems</CardTitle>
                        </CardHeader>
                         <CardContent className='flex flex-col justify-around h-full space-y-4'>
                             <div className='text-center'>
                                 <p className='text-muted-foreground'>RPM</p>
                                 <p className='font-mono text-5xl font-bold'>{engine.rpm.toFixed(0)}</p>
                             </div>
                             <Separator />
                              <div className='grid grid-cols-2 gap-4 text-center'>
                                  <div>
                                     <p className='text-muted-foreground text-sm'>Temperature</p>
                                     <p className={`font-mono text-2xl ${tempColor}`}>{engine.temperature.toFixed(1)} <span className='text-sm'>°C</span></p>
                                  </div>
                                   <div>
                                     <p className='text-muted-foreground text-sm'>Oil Pressure</p>
                                     <p className={`font-mono text-2xl ${pressureColor}`}>{engine.oilPressure.toFixed(1)} <span className='text-sm'>bar</span></p>
                                  </div>
                              </div>
                         </CardContent>
                    </Card>
                </div>

                {/* Right Column: Tanks */}
                <div className='lg:col-span-1 space-y-6'>
                    <Card>
                         <CardHeader>
                            <CardTitle className='flex items-center gap-2'><Droplets/> Tank Levels</CardTitle>
                        </CardHeader>
                         <CardContent className='space-y-6 pt-2'>
                             <div>
                                 <div className='mb-2 flex justify-between'>
                                     <span className='text-muted-foreground'>Fuel</span>
                                     <span className={`font-mono font-semibold ${fuelTextColor}`}>{tanks.fuel.toFixed(0)}%</span>
                                 </div>
                                 <Progress value={tanks.fuel} className={`h-6 ${fuelProgressClass}`}/>
                             </div>
                              <div>
                                  <div className='mb-2 flex justify-between'>
                                     <span className='text-muted-foreground'>Water</span>
                                     <span className='font-mono font-semibold'>{tanks.water.toFixed(0)}%</span>
                                 </div>
                                 <Progress value={tanks.water} className="h-6" />
                             </div>
                         </CardContent>
                    </Card>
                </div>
            </div>
        </div>
    );
}

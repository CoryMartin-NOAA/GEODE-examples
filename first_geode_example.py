import datetime
import geode
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature

# simple to start, let's get ATMS NOAA-20 data ch 1 for a single cycle and plot it
start_time = datetime.datetime(2026,9,13,3,0,tzinfo=datetime.UTC)
end_time = datetime.datetime(2026,9,13,9,0,tzinfo=datetime.UTC)
result = geode.get("atms_n20", start_time, end_time, filters=[{"channels": [1]}])
print(result)

# plot the data
plt.figure(figsize=(10, 5))
ax = plt.axes(projection=ccrs.PlateCarree())
ax.add_feature(cfeature.OCEAN, facecolor="#e8f1f8", zorder=0)
ax.add_feature(cfeature.LAND, facecolor="#f2f0e6", zorder=0)
ax.coastlines(resolution="110m", linewidth=0.7, zorder=2)
ax.add_feature(cfeature.BORDERS, linestyle=":", linewidth=0.5, zorder=2)
sc = plt.scatter(result["MetaData/longitude"],
                    result["MetaData/latitude"],
                    c=result["ObsValue/brightnessTemperature"],
                    cmap="viridis",
                    vmin=170,
                    vmax=320,
                    s=10,
                    transform=ccrs.PlateCarree(),
                    zorder=3)
plt.colorbar(sc, label="Brightness Temperature")
plt.title("ATMS NOAA-20 Channel 1")
plt.savefig("plot.png")
plt.close()


# now let's grab radiosondes over CONUS for the whole day
start_time = datetime.datetime(2026,9,13,0,0,tzinfo=datetime.UTC)
end_time = datetime.datetime(2026,9,13,23,59,tzinfo=datetime.UTC)
result = geode.get("radiosonde", start_time, end_time, filters=[{"region": "conus"}])
print(result)
# plot radiosonde locations over CONUS
plt.figure(figsize=(10, 5))
ax = plt.axes(projection=ccrs.PlateCarree())
ax.add_feature(cfeature.OCEAN, facecolor="#e8f1f8", zorder=0)
ax.add_feature(cfeature.LAND, facecolor="#f2f0e6", zorder=0)
ax.coastlines(resolution="110m", linewidth=0.7, zorder=2)
ax.add_feature(cfeature.BORDERS, linestyle=":", linewidth=0.5, zorder=2)
ax.add_feature(cfeature.STATES, edgecolor="gray", facecolor="none", linewidth=0.4, zorder=2)
# color by pressure so each balloon's ascent is visible (surface = high pressure)
sc = plt.scatter(result["MetaData/longitude"],
                    result["MetaData/latitude"],
                    c=result["MetaData/pressure"],
                    cmap="viridis_r",
                    s=3,
                    transform=ccrs.PlateCarree(),
                    zorder=3)
plt.colorbar(sc, label="Pressure")
plt.title("Radiosonde Ascents over CONUS (colored by pressure)")
plt.savefig("radiosonde_plot.png")
plt.close()

# let's get only station pressure from radiosondes but globally
start_time = datetime.datetime(2026,9,13,0,0,tzinfo=datetime.UTC)
end_time = datetime.datetime(2026,9,13,23,59,tzinfo=datetime.UTC)
result = geode.get("radiosonde", start_time, end_time, filters=[{"variables": ["ObsValue/stationPressure"]}])
print(result)
# plot global radiosonde station pressure locations
plt.figure(figsize=(10, 5))
ax = plt.axes(projection=ccrs.PlateCarree())
ax.add_feature(cfeature.OCEAN, facecolor="#e8f1f8", zorder=0)
ax.add_feature(cfeature.LAND, facecolor="#f2f0e6", zorder=0)
ax.coastlines(resolution="110m", linewidth=0.7, zorder=2)
ax.add_feature(cfeature.BORDERS, linestyle=":", linewidth=0.5, zorder=2)
sc = plt.scatter(result["MetaData/longitude"],
                    result["MetaData/latitude"],
                    c=result["ObsValue/stationPressure"],
                    cmap="viridis_r",
                    s=3,
                    transform=ccrs.PlateCarree(),
                    zorder=3)
plt.colorbar(sc, label="Station Pressure")
plt.title("Global Radiosonde Station Pressure")
plt.savefig("radiosonde_station_pressure_plot.png")
plt.close()

# finally let's define a bounding box over Tasmania and grab CrIS N21 data
tasmania_bbox = {'min_lat': -44.0, 'max_lat': -40.0, 'min_lon': 144.0, 'max_lon': 148.0}
start_time = datetime.datetime(2026,9,13,0,0,tzinfo=datetime.UTC)
end_time = datetime.datetime(2026,9,13,23,59,tzinfo=datetime.UTC)
result = geode.get("cris_n21", start_time, end_time, filters=[{"bounding_box": tasmania_bbox}, {"channels": [19]}])
print(result)
# plot CrIS N21 locations over Tasmania
plt.figure(figsize=(10, 5))
ax = plt.axes(projection=ccrs.PlateCarree())
ax.add_feature(cfeature.OCEAN, facecolor="#e8f1f8", zorder=0)
ax.add_feature(cfeature.LAND, facecolor="#f2f0e6", zorder=0)
ax.coastlines(resolution="110m", linewidth=0.7, zorder=2)
ax.add_feature(cfeature.BORDERS, linestyle=":", linewidth=0.5, zorder=2)
sc = plt.scatter(result["MetaData/longitude"],
                    result["MetaData/latitude"],
                    c=result["ObsValue/spectralRadiance"],
                    cmap="viridis",
                    s=10,
                    transform=ccrs.PlateCarree(),
                    zorder=3)
plt.colorbar(sc, label="Spectral Radiance")
plt.title("CrIS N21 Channel 19 over Tasmania")
plt.savefig("cris_n21_plot.png")
plt.close()

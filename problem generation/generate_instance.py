import random
import math
import matplotlib.pyplot as plt
import numpy as np
from scipy.spatial import distance
import pandas as pd


#def generate_point(radius_sq):
  #  #https://stackoverflow.com/questions/30564015/how-to-generate-random-points-in-a-circular-distribution
   # r_squared, theta = [random.randint(1, radius_sq), 2*math.pi*random.random()]
   # x = math.sqrt(r_squared)*math.cos(theta)
   # y = math.sqrt(r_squared)*math.sin(theta)
   # return [x, y]

#def generate_n_points(radius_sq, n):
   # return np.array([generate_point(radius_sq) for i in range(n)])

def generate_points(radius, num_points):
    #https://stackoverflow.com/questions/5837572/generate-a-random-point-within-a-circle-uniformly/5838055#5838055
    
    # radius of the circle
    circle_r = math.sqrt(radius)
    x = []
    y = []

    for i in range(num_points):
        # random angle
        alpha = 2 * math.pi * random.random()
        # random radius
        u = random.random() + random.random()
        r = circle_r * (2 - u if u > 1 else u)
        # calculating coordinates
        x.append(r * math.cos(alpha))
        y.append(r * math.sin(alpha))
    return x, y

def draw_instance(radius, x, y):
    #https://stackoverflow.com/questions/9215658/plot-a-circle-with-pyplot

    circle = plt.Circle((0, 0), radius, color='blue', fill=False, ls=':')
    depot = plt.Circle((0,0), 0.05, color='black', fill=True)

    fig, ax = plt.subplots() 

    fig.set_figheight(8)
    fig.set_figwidth(8)
    ax.set_xlim((-4, 4))
    ax.set_ylim((-4, 4))
    ax.set_title(f"{len(x)} clients")

    ax.add_patch(circle)
    ax.add_patch(depot)

    ax.scatter(x,y)

    plt.show()
    return

def calc_dist(point1, point2):
    return np.linalg.norm(point1 - point2)

def dist_to_below(all_points, index):
    row = [0] + [calc_dist(all_points[index], all_points[i]) \
                 for i in range(index+1, all_points.shape[0])]
    return np.array(row)

def get_travel_times(all_points):
    travel_times = dist_to_below(all_points, 0)
    for i in range(1, all_points.shape[0]):
        row = dist_to_below(all_points, i)
        row = np.hstack((np.zeros(all_points.shape[0]-len(row)), row))
        travel_times = np.vstack((travel_times, row))
    travel_times = np.ceil(travel_times)
    return pd.DataFrame(travel_times + travel_times.T)

def generate_service_times(travel_times_df, all_points, l):
    earliest = np.sort(travel_times_df[0])[1] + 1
    latest = l - travel_times_df.max().max() - 1
    service_start = np.array([random.randint(earliest, latest) for i in range(len(all_points)-1)])
    return pd.DataFrame(np.array((service_start, np.ones((travel_times_df.shape[0]-1)))).T,
                          columns=["Start time", "Duration"])

#def generate_providers(num_providers, p):
   # costs = np.array([random.randint(10,25) for i in range(num_providers)])
    # 4 is for generating start times from 0, 1, 2, or 3
   # start_times = np.random.choice(4, size=num_providers, replace=True, p=p)
   # return pd.DataFrame(np.array((costs, start_times)).T,
         #               columns=["cost", "start time"])
        
def generate_providers(num_providers):
    costs = np.array([random.randint(10,25) for i in range(num_providers)])
    # 4 is for generating start times from 0, 1, 2, or 3
    start_times = np.array([0 for i in range(num_providers)])
    return pd.DataFrame(np.array((costs, start_times)).T,
                        columns=["cost", "start time"])
        
def generate_general(l, providers_df, clients_df):
    col1 = np.array(("Work day duration", "Number of providers", "Number of clients"))
    col2 = np.array((l, providers_df.shape[0], clients_df.shape[0])).astype('int')
    return pd.DataFrame(np.array((col1, col2)).T)